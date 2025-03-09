//
//  WindowSelectorViewModel.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import SwiftUI
import Combine

/// View model for the window selection tool
class WindowSelectorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether window selection is active
    @Published var isSelecting: Bool = false
    
    /// Currently selected window info
    @Published var selectedWindow: WindowInfo?
    
    /// Mouse position during selection
    @Published var mousePosition: CGPoint = .zero
    
    /// Window type created from selection
    @Published var createdWindowType: WindowType?
    
    /// Status message for user feedback
    @Published var statusMessage: String = "Ready to select a window"
    
    /// Highlighted window at current position
    @Published var highlightedWindow: WindowInfo?
    
    /// Whether any processing is in progress
    @Published var isProcessing: Bool = false
    
    // MARK: - Private Properties
    
    /// Window manager for window detection
    private let windowManager: WindowManager
    
    /// Timer for polling mouse position
    private var mouseTrackingTimer: Timer?
    
    /// Event monitor for mouse clicks
    private var clickMonitor: Any?
    
    /// Event monitor for escape key to cancel selection
    private var escapeMonitor: Any?
    
    /// List of previously highlighted windows
    private var previousHighlights: [Int] = []
    
    /// Common title pattern tokens to recognize for poker tables
    private let commonPokerTokens = [
        "poker", "holdem", "hold'em", "omaha", "tournament",
        "texas", "table", "cash", "sit & go", "sit n go",
        "pokerstars", "partypoker", "888poker", "ggpoker", "winamax"
    ]
    
    /// Common application identifiers for poker clients
    private let knownPokerClients = [
        "com.pokerstars", "com.partypoker", "com.888poker", "com.ggpoker",
        "com.winamax", "com.fulltilt", "com.bodog", "com.ignition",
        "app.pokerstars", "app.partypoker", "app.888poker"
    ]
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    deinit {
        stopSelection()
    }
    
    // MARK: - Public Methods
    
    /// Starts window selection mode
    func startSelection() {
        isSelecting = true
        isProcessing = false
        selectedWindow = nil
        createdWindowType = nil
        highlightedWindow = nil
        previousHighlights = []
        statusMessage = "Hover over a window and click to select it"
        
        // Start tracking mouse position
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
        
        // Install event monitor for mouse clicks
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseClick(at: NSEvent.mouseLocation)
        }
        
        // Install event monitor for escape key to cancel
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.stopSelection()
            }
        }
        
        Logger.log("Started window selection mode", level: .info)
    }
    
    /// Stops window selection mode
    func stopSelection() {
        // Clean up timers and monitors
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        
        if let clickMonitor = clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        
        if let escapeMonitor = escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        
        // Update state on the main thread asynchronously to avoid SwiftUI update cycle issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isSelecting = false
            self.highlightedWindow = nil
            
            if self.createdWindowType == nil && self.selectedWindow == nil {
                self.statusMessage = "Window selection canceled"
            }
        }
        
        Logger.log("Stopped window selection mode", level: .info)
    }
    
    /// Creates a window type from the selected window
    /// - Returns: Created window type or nil if no window selected
    func createWindowTypeFromSelection() -> WindowType? {
        guard let selectedWindow = selectedWindow else {
            statusMessage = "No window selected"
            return nil
        }
        
        // Set processing flag
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = true
        }
        
        // Create a window type from the selected window
        let windowType = WindowType(
            id: UUID().uuidString,
            name: generateWindowTypeName(from: selectedWindow),
            titlePattern: createTitlePattern(from: selectedWindow.title),
            classPattern: createClassPattern(from: selectedWindow.windowClass),
            enabled: true
        )
        
        // Update UI state asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.createdWindowType = windowType
            self?.statusMessage = "Window type created: \(windowType.name)"
            self?.isProcessing = false
        }
        
        Logger.log("Created window type: \(windowType.name) with pattern: \(windowType.titlePattern)", level: .info)
        
        return windowType
    }
    
    /// Tests if the created window type matches the selected window
    /// - Returns: True if the window type matches
    func testWindowTypeMatch() -> Bool {
        guard let windowType = createdWindowType, let window = selectedWindow else {
            // Update message asynchronously to avoid view update cycle issues
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = "No window type or window to test"
            }
            return false
        }
        
        // Set processing flag asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = true
        }
        
        // Test if the window type matches the selected window
        let matches = windowType.matches(title: window.title, windowClass: window.windowClass)
        
        // Update status message asynchronously
        DispatchQueue.main.async { [weak self] in
            if matches {
                self?.statusMessage = "✅ Window type successfully matches the selected window"
            } else {
                self?.statusMessage = "❌ Window type does not match the selected window"
            }
            self?.isProcessing = false
        }
        
        Logger.log("Tested window type match: \(matches)", level: .info)
        
        return matches
    }
    
    /// Creates a refined window type that matches similar windows
    /// - Returns: Refined window type
    func createRefinedWindowType() -> WindowType? {
        guard let baseWindowType = createdWindowType, let selectedWindow = selectedWindow else {
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = "No window type or window to refine"
            }
            return nil
        }
        
        // Set processing flag asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = true
        }
        
        // Get all windows from the system
        let allWindows = getAllVisibleWindowInfo()
        
        // Find similar windows by comparing application
        let similarWindows = allWindows.filter { window in
            // Match by application class
            let sameClass = window.windowClass == selectedWindow.windowClass
            
            // Don't include the exact same window
            let notSameWindow = window.id != selectedWindow.id
            
            return sameClass && notSameWindow
        }
        
        // If we found similar windows, refine the title pattern
        var refinedTitlePattern = baseWindowType.titlePattern
        
        if !similarWindows.isEmpty {
            // Find common pattern between titles
            let titles = [selectedWindow.title] + similarWindows.map { $0.title }
            refinedTitlePattern = findCommonTitlePattern(titles)
        }
        
        // Create refined window type
        let refinedType = WindowType(
            id: UUID().uuidString,
            name: baseWindowType.name,
            titlePattern: refinedTitlePattern,
            classPattern: baseWindowType.classPattern,
            enabled: true
        )
        
        // Test how many windows this refined type will match
        let matchCount = allWindows.filter { window in
            refinedType.matches(title: window.title, windowClass: window.windowClass)
        }.count
        
        // Update UI state asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.createdWindowType = refinedType
            self?.statusMessage = "Refined window type will match \(matchCount) similar windows"
            self?.isProcessing = false
        }
        
        Logger.log("Created refined window type with pattern: \(refinedTitlePattern), matching \(matchCount) windows", level: .info)
        
        return refinedType
    }
    
    // MARK: - Helper Methods
    
    /// Generates a name for a window type based on window info
    func generateWindowTypeName(from windowInfo: WindowInfo) -> String {
        // First, check if it's a known poker client
        let isKnownClient = knownPokerClients.contains { clientID in
            windowInfo.windowClass.lowercased().contains(clientID.lowercased())
        }
        
        // Extract app name from window class
        var appName = "Unknown"
        
        // Try to extract from bundle ID (e.g., com.pokerstars.client -> PokerStars)
        let components = windowInfo.windowClass.components(separatedBy: ".")
        if components.count > 1 {
            let lastComponent = components.last ?? ""
            
            if lastComponent.lowercased() == "app" || lastComponent.lowercased() == "client" {
                // Use second to last component if last is just "app" or "client"
                if components.count > 2 {
                    appName = components[components.count - 2].capitalized
                }
            } else {
                appName = lastComponent.capitalized
            }
        }
        
        // For known clients, use better capitalization
        if isKnownClient {
            if windowInfo.windowClass.lowercased().contains("pokerstars") {
                appName = "PokerStars"
            } else if windowInfo.windowClass.lowercased().contains("partypoker") {
                appName = "PartyPoker"
            } else if windowInfo.windowClass.lowercased().contains("888poker") {
                appName = "888poker"
            } else if windowInfo.windowClass.lowercased().contains("ggpoker") {
                appName = "GGPoker"
            } else if windowInfo.windowClass.lowercased().contains("winamax") {
                appName = "Winamax"
            }
        }
        
        // Extract table information from title
        var tableInfo = ""
        
        // Check for common patterns in poker table titles
        let lowercaseTitle = windowInfo.title.lowercased()
        
        // Extract table number or ID
        if let tableNumberRange = lowercaseTitle.range(of: "table [0-9]+", options: .regularExpression) {
            tableInfo = String(windowInfo.title[tableNumberRange])
        } else if let tableIDRange = lowercaseTitle.range(of: "#[0-9]+", options: .regularExpression) {
            tableInfo = String(windowInfo.title[tableIDRange])
        } else if let numberRange = lowercaseTitle.range(of: "[0-9]{4,}", options: .regularExpression) {
            // If there's a number with at least 4 digits, it might be a table ID
            tableInfo = "Table " + String(windowInfo.title[numberRange])
        }
        
        // Construct name
        var name = appName
        
        if !tableInfo.isEmpty {
            name += " - " + tableInfo
        } else if isKnownClient {
            name += " Table"
        } else {
            // If not a poker client or no table info found, use a portion of the title
            var shortTitle = windowInfo.title
            if shortTitle.count > 20 {
                shortTitle = String(shortTitle.prefix(17)) + "..."
            }
            name += " - " + shortTitle
        }
        
        return name
    }
    
    /// Creates a title pattern with wildcards from a window title
    func createTitlePattern(from title: String) -> String {
        // Convert to lowercase for easier pattern matching
        let lowercaseTitle = title.lowercased()
        
        // Check if it's likely a poker table
        let isLikelyPokerTable = commonPokerTokens.contains { token in
            lowercaseTitle.contains(token)
        }
        
        // Different strategies based on type of window
        if isLikelyPokerTable {
            // For poker tables, extract key parts of the title
            
            // Strategy 1: Extract game type (Hold'em, Omaha, etc.)
            var gameType = ""
            if lowercaseTitle.contains("hold'em") || lowercaseTitle.contains("holdem") {
                gameType = "Hold'em"
            } else if lowercaseTitle.contains("omaha") {
                gameType = "Omaha"
            }
            
            // Strategy 2: Extract "Table" part if present
            var hasTable = lowercaseTitle.contains("table")
            
            // Create pattern based on findings
            if !gameType.isEmpty && hasTable {
                return "*\(gameType)*Table*"
            } else if !gameType.isEmpty {
                return "*\(gameType)*"
            } else if hasTable {
                return "*Table*"
            }
            
            // Strategy 3: For poker rooms, use brand name
            if lowercaseTitle.contains("pokerstars") {
                return "*PokerStars*"
            } else if lowercaseTitle.contains("partypoker") {
                return "*PartyPoker*"
            } else if lowercaseTitle.contains("888poker") {
                return "*888poker*"
            }
        }
        
        // Default strategy: Add wildcards at the beginning and end
        return "*\(title)*"
    }
    
    /// Creates a class pattern for a window class
    func createClassPattern(from windowClass: String) -> String {
        // For bundle IDs, we usually want an exact match or a prefix match
        if windowClass.contains(".") {
            // For known poker clients, use a prefix match
            if knownPokerClients.contains(where: { windowClass.lowercased().contains($0.lowercased()) }) {
                // Extract the first two components of the bundle ID
                let components = windowClass.components(separatedBy: ".")
                if components.count >= 2 {
                    return "\(components[0]).\(components[1])*"
                }
            }
            
            // For other apps, use the exact bundle ID
            return windowClass
        }
        
        // For app names or unknown classes, use wildcard matching
        return "*\(windowClass)*"
    }
    
    // MARK: - Private Methods
    
    /// Updates the current mouse position and highlights windows
    private func updateMousePosition() {
        let location = NSEvent.mouseLocation
        
        // Update mouse position on main thread
        DispatchQueue.main.async { [weak self] in
            self?.mousePosition = location
        }
        
        // Update highlighted window at mouse position
        if isSelecting {
            // Get window info at current position
            if let windowInfo = windowManager.pickWindowAt(screenPosition: location) {
                // Only update if it's a different window
                if highlightedWindow?.id != windowInfo.id {
                    // Update UI asynchronously
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.highlightedWindow = windowInfo
                        
                        // Keep track of recently highlighted windows (avoid flicker)
                        self.previousHighlights.append(windowInfo.id)
                        if self.previousHighlights.count > 5 {
                            self.previousHighlights.removeFirst()
                        }
                        
                        // Update status with window info
                        self.statusMessage = "Hover: \(windowInfo.title)"
                    }
                }
            } else {
                // Only clear if we're not hovering over a recently highlighted window
                // This helps with flickering when the mouse is near window edges
                if previousHighlights.isEmpty || !previousHighlights.contains(where: { $0 == highlightedWindow?.id }) {
                    DispatchQueue.main.async { [weak self] in
                        self?.highlightedWindow = nil
                        self?.statusMessage = "Hover over a window and click to select it"
                    }
                }
            }
        }
    }
    
    /// Handles a mouse click during selection
    /// - Parameter location: Location of the click
    private func handleMouseClick(at location: CGPoint) {
        guard isSelecting else { return }
        
        // Get window info at click location
        if let windowInfo = windowManager.pickWindowAt(screenPosition: location) {
            // Update state on the main thread asynchronously
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.selectedWindow = windowInfo
                self.statusMessage = "Selected window: \(windowInfo.title)"
                
                // Create a window type suggestion
                self.createdWindowType = WindowType(
                    id: UUID().uuidString,
                    name: self.generateWindowTypeName(from: windowInfo),
                    titlePattern: self.createTitlePattern(from: windowInfo.title),
                    classPattern: self.createClassPattern(from: windowInfo.windowClass),
                    enabled: true
                )
                
                // Exit selection mode
                self.isSelecting = false
            }
            
            Logger.log("Selected window: id=\(windowInfo.id), title=\(windowInfo.title), class=\(windowInfo.windowClass)", level: .info)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = "No window found at click location"
            }
        }
    }
    
    /// Gets a list of all visible windows
    private func getAllVisibleWindowInfo() -> [WindowInfo] {
        var results: [WindowInfo] = []
        
        // Get all windows using CGWindowListCopyWindowInfo
        if let windowInfos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            for windowInfo in windowInfos {
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
                      // Skip windows that aren't visible
                      windowInfo[kCGWindowAlpha as String] as? Float ?? 1.0 > 0.0
                else {
                    continue
                }
                
                let windowFrame = CGRect(x: x, y: y, width: width, height: height)
                let windowClass = getWindowClassForPID(pid)
                
                let info = WindowInfo(
                    id: windowID,
                    pid: pid,
                    title: windowTitle,
                    windowClass: windowClass,
                    frame: windowFrame
                )
                
                results.append(info)
            }
        }
        
        return results
    }
    
    /// Gets the window class for a process ID
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
        
        return "unknown"
    }
    
    /// Finds a common pattern from multiple title strings
    /// - Parameter titles: Array of title strings
    /// - Returns: Common pattern with wildcards
    private func findCommonTitlePattern(_ titles: [String]) -> String {
        guard !titles.isEmpty else { return "*" }
        
        // If only one title, use the standard pattern creation
        if titles.count == 1 {
            return createTitlePattern(from: titles[0])
        }
        
        // Convert all titles to lowercase for comparison
        let lowerTitles = titles.map { $0.lowercased() }
        
        // Find common substrings
        var commonWords = Set<String>()
        var firstTitle = true
        
        for title in lowerTitles {
            // Split into words
            let words = title.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 2 } // Ignore very short words
            
            if firstTitle {
                // Initialize with all words from first title
                commonWords = Set(words)
                firstTitle = false
            } else {
                // Keep only words that appear in both titles
                commonWords = commonWords.intersection(words)
            }
        }
        
        // Check if we found any common words
        if commonWords.isEmpty {
            // No common words, use first title as pattern
            return createTitlePattern(from: titles[0])
        }
        
        // Sort common words by frequency across all titles
        let sortedWords = Array(commonWords).sorted { word1, word2 in
            let count1 = lowerTitles.filter { $0.contains(word1) }.count
            let count2 = lowerTitles.filter { $0.contains(word2) }.count
            return count1 > count2
        }
        
        // Use the most common words (up to 2) for the pattern
        var pattern = "*"
        for i in 0..<min(2, sortedWords.count) {
            pattern += "\(sortedWords[i])*"
        }
        
        return pattern
    }
}
