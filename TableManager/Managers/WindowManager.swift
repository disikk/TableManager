//
//  WindowManager.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import Cocoa
import Combine
import ApplicationServices  // Основной фреймворк содержащий AX константы
import Accessibility

/// Manages window detection and manipulation using macOS Accessibility API
class WindowManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently detected windows that match our criteria
    @Published private(set) var detectedWindows: [ManagedWindow] = []
    
    /// Windows currently being managed/arranged by the app
    @Published private(set) var managedWindows: [ManagedWindow] = []
    
    /// Published status for UI updates
    @Published private(set) var status: WindowManagerStatus = .idle
    
    // MARK: - Private Properties
    
    /// Window types to detect and manage
    private var windowTypes: [WindowType] = []
    
    /// Timer for periodic window detection
    private var detectionTimer: Timer?
    
    /// Detection frequency in seconds
    private var detectionInterval: TimeInterval = 1.0
    
    /// Queue for window operations
    private let operationQueue = DispatchQueue(label: "com.tablemanager.windowManager", qos: .userInitiated)
    
    /// Access to user defaults for settings
    private let defaults = UserDefaults.standard
    
    /// Timer for checking mouse hover
    private var hoverTimer: Timer?
    
    /// Last window ID that was hovered
    private var lastHoveredWindowID: Int?
    
    /// Time when hovering started over a window
    private var hoverStartTime: Date?
    
    /// Last time a window was activated
    private var lastActivationTime: Date?
    
    /// Minimum time between window activations (to prevent rapid switching)
    private let activationCooldown: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    init() {
        // Request accessibility permissions if needed
        checkAccessibilityPermissions()
        
        // Load detection interval from preferences
        if let interval = defaults.object(forKey: "detectionInterval") as? TimeInterval {
            detectionInterval = interval
        }
        
        // Setup notifications for screen changes
        setupScreenChangeNotifications()
        
        // Start hover detection if enabled
        checkAndStartHoverDetection()
    }
    
    deinit {
        // Остановка таймеров
        detectionTimer?.invalidate()
        detectionTimer = nil
        
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        // Удаление наблюдателей уведомлений
        NotificationCenter.default.removeObserver(self)
        
        // Освобождение ресурсов работы с окнами
        managedWindows.removeAll()
        
        Logger.log("WindowManager properly deallocated", level: .debug)
    }
    
    // MARK: - Window Detection Methods
    
    /// Starts monitoring for windows matching the provided window types
    /// - Parameter windowTypes: Array of window types to detect
    func startDetection(windowTypes: [WindowType]) {
        self.windowTypes = windowTypes.filter { $0.enabled }
        
        if self.windowTypes.isEmpty {
            Logger.log("No enabled window types to detect", level: .warning)
            status = .noWindows
            return
        }
        
        status = .detecting
        
        // Start periodic detection
        detectionTimer?.invalidate()
        detectionTimer = Timer.scheduledTimer(withTimeInterval: detectionInterval, repeats: true) { [weak self] _ in
            self?.detectWindows()
        }
        
        // Initial detection
        detectWindows()
        
        Logger.log("Started window detection with \(self.windowTypes.count) window types", level: .info)
    }
    
    /// Stops window detection
    func stopDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
        status = .idle
        Logger.log("Stopped window detection", level: .info)
    }
    
    /// Refreshes window detection once
    func refreshDetection() {
        Logger.log("Manual window detection refresh triggered", level: .info)
        detectWindows()
    }
    
    /// Updates detection interval
    /// - Parameter interval: New interval in seconds
    func updateDetectionInterval(_ interval: TimeInterval) {
        detectionInterval = interval
        defaults.set(interval, forKey: "detectionInterval")
        
        // Restart detection with new interval if active
        if detectionTimer != nil {
            stopDetection()
            startDetection(windowTypes: windowTypes)
        }
        
        Logger.log("Detection interval updated to \(interval) seconds", level: .info)
    }
    
    // MARK: - Hover Activation Methods
    
    /// Starts monitoring mouse hover for window activation
    func startHoverDetection() {
        // Stop existing hover detection first
        stopHoverDetection()
        
        // Start hover detection if enabled in preferences
        if defaults.bool(forKey: "enableHoverActivation") {
            Logger.log("Starting hover detection for window activation", level: .info)
            
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkMouseHover()
            }
        }
    }
    
    /// Stops hover detection
    func stopHoverDetection() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        lastHoveredWindowID = nil
        hoverStartTime = nil
        
        Logger.log("Stopped hover detection", level: .info)
    }
    
    /// Checks if hover detection should be running based on settings
    func checkAndStartHoverDetection() {
        if defaults.bool(forKey: "enableHoverActivation") {
            startHoverDetection()
        } else {
            stopHoverDetection()
        }
    }
    
    /// Updates hover detection based on settings change
    func updateHoverSettings() {
        checkAndStartHoverDetection()
    }
    
    // MARK: - Layout Application
    
    /// Arranges windows according to the provided layout
    /// - Parameter layout: Layout to apply to managed windows
    func applyLayout(_ layout: Layout) {
        guard !managedWindows.isEmpty else {
            Logger.log("No windows to arrange", level: .warning)
            return
        }
        
        status = .arranging
        Logger.log("Applying layout: \(layout.name) to \(managedWindows.count) windows", level: .info)
        
        // Match windows to slots based on layout's matching strategy
        let assignments = layout.assignWindowsToSlots(windows: managedWindows)
        
        // Apply window positions and sizes based on slot assignments
        let enableAnimations = defaults.bool(forKey: "enableAnimations")
        
        operationQueue.async { [weak self] in
            for (window, slot) in assignments {
                self?.moveWindow(window, toSlot: slot, animated: enableAnimations)
            }
            
            // Small delay to ensure all windows are moved before changing status
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.status = .monitoring
                Logger.log("Layout applied successfully", level: .info)
            }
        }
    }
    
    /// Captures the current layout of detected windows
    /// - Returns: A Layout object representing the current window positions
    func captureCurrentLayout() -> Layout {
        Logger.log("Capturing current layout with \(detectedWindows.count) windows", level: .info)
        
        let slots = detectedWindows.enumerated().map { index, window -> Slot in
            return Slot(
                id: "\(index / 4)_\(index % 4)", // Create a grid-like ID pattern
                frame: window.frame,
                displayID: window.displayID,
                priority: 0
            )
        }
        
        return Layout(
            id: UUID().uuidString,
            name: "Captured Layout",
            slots: slots,
            matchingStrategy: .sequential
        )
    }
    
    /// Picks a window at the given screen position
    /// - Parameter screenPosition: Position on screen to pick a window
    /// - Returns: Window information if found, nil otherwise
    func pickWindowAt(screenPosition: CGPoint) -> WindowInfo? {
        Logger.log("Picking window at position: \(screenPosition.x), \(screenPosition.y)", level: .debug)
        
        // Получаем список окон с дополнительными параметрами
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            Logger.log("Failed to get window list", level: .error)
            return nil
        }
        
        // Улучшенная фильтрация системных элементов
        let systemBundleIDs = [
            "com.apple.dock", "com.apple.WindowManager", "com.apple.systemuiserver",
            "com.apple.notificationcenterui", "com.apple.controlcenter", "com.apple.finder"
        ]
        
        // Сортируем по слою и фильтруем невидимые окна
        let matchingWindows = windows.compactMap { windowInfo -> (WindowInfo, Int)? in
            guard let windowID = windowInfo[kCGWindowNumber as String] as? Int,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? Int,
                  let windowBounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = windowBounds["X"] as? CGFloat,
                  let y = windowBounds["Y"] as? CGFloat,
                  let width = windowBounds["Width"] as? CGFloat,
                  let height = windowBounds["Height"] as? CGFloat,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  let alpha = windowInfo[kCGWindowAlpha as String] as? Float,
                  width > 10, height > 10, // Игнорируем слишком маленькие окна
                  alpha > 0.1 // Игнорируем прозрачные окна
            else {
                return nil
            }
            
            // Проверяем принадлежность к системным приложениям
            let windowClass = getWindowClassForPID(pid)
            if systemBundleIDs.contains(where: { windowClass.hasPrefix($0) }) {
                return nil
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Проверяем, содержит ли окно указанную точку
            if frame.contains(screenPosition) {
                let title = windowInfo[kCGWindowName as String] as? String ?? ""
                let info = WindowInfo(
                    id: windowID,
                    pid: pid,
                    title: title,
                    windowClass: windowClass,
                    frame: frame
                )
                return (info, layer)
            }
            
            return nil
        }
        .sorted { $0.1 < $1.1 } // Сортировка по слою (меньшие значения находятся сверху)
        
        if let topWindow = matchingWindows.first {
            Logger.log("Found window: \(topWindow.0.title), Class: \(topWindow.0.windowClass)", level: .debug)
            return topWindow.0
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Checks and requests accessibility permissions if needed
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            Logger.log("Accessibility permissions needed for window management", level: .warning)
            // The system will show a prompt to enable accessibility
        } else {
            Logger.log("Accessibility permissions already granted", level: .info)
        }
    }
    
    /// Sets up notifications for screen configuration changes
    private func setupScreenChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Add observer for hover activation setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHoverSettingsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    /// Handles screen configuration changes
    @objc private func handleScreenChange(_ notification: Notification) {
        Logger.log("Screen configuration changed, refreshing window detection", level: .info)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshDetection()
        }
    }
    
    /// Handles changes to hover activation settings
    @objc private func handleHoverSettingsChange(_ notification: Notification) {
        // Check for changes to hover activation settings
        if notification.object as? UserDefaults == UserDefaults.standard {
            checkAndStartHoverDetection()
        }
    }
    
    /// Detects windows matching the configured window types
    private func detectWindows() {
        // Early return if no window types configured
        guard !windowTypes.isEmpty else {
            detectedWindows = []
            return
        }
        
        // Get all windows from Accessibility API
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            Logger.log("Failed to get window list", level: .error)
            return
        }
        
        var newDetectedWindows: [ManagedWindow] = []
        
        // Process each window
        for windowInfo in windows {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? Int,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? Int,
                  let windowTitle = windowInfo[kCGWindowName as String] as? String,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  // Skip windows with zero width or height
                  width > 0, height > 0,
                  // Skip windows that aren't visible (Apple adds alpha)
                  windowInfo[kCGWindowAlpha as String] as? Float ?? 1.0 > 0.0
            else {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            let windowClass = getWindowClassForPID(pid)
            
            // Check if window matches any of our window types
            for windowType in windowTypes {
                if windowType.matches(title: windowTitle, windowClass: windowClass) {
                    // Get display ID for the window
                    let displayID = getDisplayIDForFrame(windowFrame)
                    
                    // Check if window is already in the list (to avoid duplicates)
                    if !newDetectedWindows.contains(where: { $0.id == windowID }) {
                        // Create managed window
                        let managedWindow = ManagedWindow(
                            id: windowID,
                            pid: pid,
                            title: windowTitle,
                            windowClass: windowClass,
                            frame: windowFrame,
                            displayID: displayID,
                            type: windowType
                        )
                        
                        newDetectedWindows.append(managedWindow)
                        Logger.log("Detected window: \(windowTitle) [\(windowType.name)]", level: .debug)
                    }
                    break
                }
            }
        }
        
        // Update detected windows
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedWindows = newDetectedWindows
            
            // Update managed windows
            self.managedWindows = newDetectedWindows
            
            // Update status
            self.status = self.managedWindows.isEmpty ? .noWindows : .monitoring
        }
    }
    
    /// Moves a window to the specified slot
    /// - Parameters:
    ///   - window: Window to move
    ///   - slot: Target slot
    ///   - animated: Whether to animate the movement
    private func moveWindow(_ window: ManagedWindow, toSlot slot: Slot, animated: Bool = false) {
        // Create AXUIElement for the window
        let app = AXUIElementCreateApplication(pid_t(window.pid))
        var windowRef: AXUIElement?
        
        // Find the specific window by its ID
        var value: CFTypeRef?
        var axError = AXUIElementCopyAttributeValue(app, "AXWindows" as CFString, &value)
        
        if axError != .success {
            Logger.log("Error getting windows for PID \(window.pid): \(axError.rawValue)", level: .error)
            return
        }
        
        guard let windows = value as? [AXUIElement] else {
            Logger.log("Could not convert windows value to array for PID \(window.pid)", level: .error)
            return
        }
        
        for axWindow in windows {
            var windowIDValue: CFTypeRef?
            axError = AXUIElementCopyAttributeValue(axWindow, "AXWindowID" as CFString, &windowIDValue)
            
            if axError != .success {
                Logger.log("Error getting window ID: \(axError.rawValue)", level: .error)
                continue
            }
            
            if let windowID = windowIDValue as? Int, windowID == window.id {
                windowRef = axWindow
                break
            }
        }
        
        // Move and resize the window
        guard let windowRef = windowRef else {
            Logger.log("Failed to find window reference for window ID: \(window.id)", level: .error)
            return
        }
        
        if animated {
            // Get current position and size
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            
            axError = AXUIElementCopyAttributeValue(windowRef, "AXPosition" as CFString, &positionValue)
            if axError != .success {
                Logger.log("Error getting window position: \(axError.rawValue)", level: .error)
                
                // Fall back to non-animated movement
                moveWindowWithoutAnimation(windowRef, to: slot)
                return
            }
            
            axError = AXUIElementCopyAttributeValue(windowRef, "AXSize" as CFString, &sizeValue)
            if axError != .success {
                Logger.log("Error getting window size: \(axError.rawValue)", level: .error)
                
                // Fall back to non-animated movement
                moveWindowWithoutAnimation(windowRef, to: slot)
                return
            }
            
            guard let positionValue = positionValue as AnyObject as? NSValue,
                  let sizeValue = sizeValue as AnyObject as? NSValue else {
                Logger.log("Failed to convert position or size values", level: .error)
                
                // Fall back to non-animated movement
                moveWindowWithoutAnimation(windowRef, to: slot)
                return
            }
            
            var currentPosition = CGPoint.zero
            var currentSize = CGSize.zero
            positionValue.getValue(&currentPosition)
            sizeValue.getValue(&currentSize)
            
            // Calculate intermediate steps for animation
            let steps = 10
            let delay = 0.01 // 10ms between steps
            
            for step in 1...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                
                // Interpolate position
                let x = currentPosition.x + (slot.frame.minX - currentPosition.x) * progress
                let y = currentPosition.y + (slot.frame.minY - currentPosition.y) * progress
                
                // Interpolate size
                let width = currentSize.width + (slot.frame.width - currentSize.width) * progress
                let height = currentSize.height + (slot.frame.height - currentSize.height) * progress
                
                // Apply intermediate position and size
                DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(step)) {
                    var point = CGPoint(x: x, y: y)
                    let pointRef = NSValue(point: point)
                    
                    axError = AXUIElementSetAttributeValue(windowRef, "AXPosition" as CFString,
                                                    pointRef as CFTypeRef)
                    if axError != .success {
                        Logger.log("Error setting window position: \(axError.rawValue)", level: .error)
                    }
                    
                    var size = CGSize(width: width, height: height)
                    let sizeRef = NSValue(size: size)
                    
                    axError = AXUIElementSetAttributeValue(windowRef, "AXSize" as CFString,
                                                    sizeRef as CFTypeRef)
                    if axError != .success {
                        Logger.log("Error setting window size: \(axError.rawValue)", level: .error)
                    }
                }
            }
        } else {
            moveWindowWithoutAnimation(windowRef, to: slot)
        }
        
        Logger.log("Moved window: \(window.title) to slot: \(slot.id)", level: .debug)
    }
    
    /// Moves a window without animation
    /// - Parameters:
    ///   - windowRef: AXUIElement reference to the window
    ///   - slot: Target slot
    private func moveWindowWithoutAnimation(_ windowRef: AXUIElement, to slot: Slot) {
        // Position without animation
        var point = CGPoint(x: slot.frame.minX, y: slot.frame.minY)
        let pointRef = NSValue(point: point)
        
        var axError = AXUIElementSetAttributeValue(windowRef, "AXPosition" as CFString,
                                          pointRef as CFTypeRef)
        if axError != .success {
            Logger.log("Error setting window position: \(axError.rawValue)", level: .error)
        }
        
        // Size without animation
        var size = CGSize(width: slot.frame.width, height: slot.frame.height)
        let sizeRef = NSValue(size: size)
        
        axError = AXUIElementSetAttributeValue(windowRef, "AXSize" as CFString,
                                      sizeRef as CFTypeRef)
        if axError != .success {
            Logger.log("Error setting window size: \(axError.rawValue)", level: .error)
        }
    }
    
    /// Checks for windows under the mouse cursor and activates if needed
    private func checkMouseHover() {
        // Получаем текущую позицию мыши
        let mousePosition = NSEvent.mouseLocation
        
        // Проверяем наличие окна под курсором
        if let windowInfo = pickWindowAt(screenPosition: mousePosition) {
            // Проверяем, является ли это одним из наших управляемых окон
            let isManaged = managedWindows.contains { $0.id == windowInfo.id }
            
            if isManaged {
                // Если мы всё ещё над тем же окном
                if lastHoveredWindowID == windowInfo.id {
                    // Проверяем время наведения против настройки задержки
                    if let startTime = hoverStartTime {
                        let hoverDelay = defaults.double(forKey: Constants.UserDefaults.hoverDelay)
                        let currentDuration = Date().timeIntervalSince(startTime)
                        
                        if currentDuration >= hoverDelay {
                            // Проверяем прошли ли мы время ожидания между активациями
                            if lastActivationTime == nil || Date().timeIntervalSince(lastActivationTime!) >= activationCooldown {
                                // Время активировать окно
                                activateWindow(windowInfo.id, pid: windowInfo.pid)
                                lastActivationTime = Date()
                                
                                // Сбрасываем отслеживание наведения для предотвращения повторных активаций
                                lastHoveredWindowID = nil
                                hoverStartTime = nil
                            }
                        }
                    }
                } else {
                    // Начали наведение на новое окно
                    lastHoveredWindowID = windowInfo.id
                    hoverStartTime = Date()
                }
            } else {
                // Не управляемое окно, очищаем состояние наведения
                lastHoveredWindowID = nil
                hoverStartTime = nil
            }
        } else {
            // Под курсором нет окна, очищаем состояние наведения
            lastHoveredWindowID = nil
            hoverStartTime = nil
        }
    }
    
    /// Activates a window by bringing it to front
    /// - Parameters:
    ///   - windowID: ID of window to activate
    ///   - pid: Process ID of window's application
    /// - Returns: Success of the operation
    private func activateWindow(_ windowID: Int, pid: Int) -> Bool {
        Logger.log("Activating window ID: \(windowID), PID: \(pid)", level: .debug)
        
        // Приводим типы к ожидаемым CGWindowID (UInt32) и pid_t (Int32)
        let cgWindowID = CGWindowID(windowID)
        let processPID = pid_t(pid)
        
        // Используем безопасный метод активации окна с обработкой ошибок
        let success = WindowUtilities.safeActivateWindow(windowID: cgWindowID, pid: processPID)
        
        if success {
            Logger.log("Successfully activated window ID: \(windowID)", level: .info)
            
            // Отправляем уведомление об успешной активации
            NotificationCenter.default.post(name: .windowActivated, object: nil, userInfo: ["windowID": windowID])
        } else {
            Logger.log("Failed to activate window ID: \(windowID)", level: .error)
            
            // Уведомляем пользователя о проблеме
            NotificationManager.shared.show("Failed to activate window. Check accessibility permissions.", type: .error)
        }
        
        return success
    }
    
    /// Gets the window class for a process
    /// - Parameter pid: Process ID
    /// - Returns: Window class string if available
    private func getWindowClassForPID(_ pid: Int) -> String {
        // Try to get application bundle identifier first
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            if let bundleID = app.bundleIdentifier {
                return bundleID
            }
            
            // If bundle ID is nil, try to get the application name
            if let appName = app.localizedName {
                return "app.\(appName.lowercased().replacingOccurrences(of: " ", with: ""))"
            }
        }
        
        // If we can't get app info, try to get process info
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "command="]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        do {
            try task.run()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Extract just the executable name from path
                let components = output.components(separatedBy: "/")
                if let executableName = components.last {
                    return "process.\(executableName.lowercased())"
                }
                return "process.\(output.lowercased())"
            }
        } catch {
            Logger.log("Error getting process info: \(error.localizedDescription)", level: .error)
        }
        
        return "unknown"
    }
    
    /// Gets the display ID for a frame
    /// - Parameter frame: Frame to check
    /// - Returns: Display ID
    private func getDisplayIDForFrame(_ frame: CGRect) -> CGDirectDisplayID {
        var displayID: CGDirectDisplayID = CGMainDisplayID()
        
        // Find which display contains the center of the window
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        
        // Get all displays
        var displayCount: UInt32 = 0
        var displayList: UnsafeMutablePointer<CGDirectDisplayID>?
        let error = CGGetActiveDisplayList(0, nil, &displayCount)
        
        if error == .success && displayCount > 0 {
            displayList = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: Int(displayCount))
            CGGetActiveDisplayList(displayCount, displayList, &displayCount)
            
            for i in 0..<displayCount {
                let display = displayList![Int(i)]
                let bounds = CGDisplayBounds(display)
                
                if bounds.contains(centerPoint) {
                    displayID = display
                    break
                }
            }
            
            displayList?.deallocate()
        }
        
        return displayID
    }
    
    /// Checks if a window is still valid (exists)
    /// - Parameter window: Window to check
    /// - Returns: True if window still exists
    private func isWindowValid(_ window: ManagedWindow) -> Bool {
        // Get all windows from Accessibility API
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        // Check if window ID still exists
        return windows.contains { ($0[kCGWindowNumber as String] as? Int) == window.id }
    }
}

// MARK: - Supporting Types

/// Status of the window manager
enum WindowManagerStatus {
    case idle
    case detecting
    case monitoring
    case arranging
    case noWindows
    case error(String)
}

/// Representation of a managed window
struct ManagedWindow: Identifiable, Equatable, Hashable {
    let id: Int
    let pid: Int
    let title: String
    let windowClass: String
    var frame: CGRect
    let displayID: CGDirectDisplayID
    let type: WindowType
    
    static func == (lhs: ManagedWindow, rhs: ManagedWindow) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Basic window information
struct WindowInfo {
    let id: Int
    let pid: Int
    let title: String
    let windowClass: String
    let frame: CGRect
}
