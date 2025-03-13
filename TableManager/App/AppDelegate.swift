//
//  AppDelegate.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Main window controller
    private var mainWindowController: NSWindowController?
    
    /// Status bar item
    private var statusItem: NSStatusItem?
    
    /// Main view model
    var mainViewModel = MainViewModel()
    
    /// Window selector view model
    private var windowSelectorViewModel: WindowSelectorViewModel?
    
    /// Registered global hotkeys
    private var hotkeyIDs: [EventHotKeyID] = []
    
    /// Hotkey references
    private var hotKeyRefs: [EventHotKeyRef?] = []
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize logger
        Logger.log("Application started", level: .info)
        
        // Create window selector view model
        windowSelectorViewModel = WindowSelectorViewModel(windowManager: mainViewModel.windowManager)
        
        // Request accessibility permissions if needed
        requestAccessibilityPermissions()
        
        // Setup menu bar item if enabled
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showInMenuBar) {
            setupStatusItem()
        }
        
        // Setup notification observers
        setupNotificationObservers()
        
        // Register global hotkeys
        registerGlobalHotkeys()
        
        // Autostart detection if enabled
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.autostartDetection) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.mainViewModel.windowManager.startDetection(windowTypes: self?.mainViewModel.configManager.windowTypes ?? [])
            }
        }
        
        // Update Dock visibility based on settings
        updateDockVisibility()
    }
    
    /// Hides/shows the app from Dock
    private func updateDockVisibility() {
        let hideFromDock = UserDefaults.standard.bool(forKey: Constants.UserDefaults.hideFromDock)
        
        if hideFromDock {
            // Hide from Dock
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Show in Dock
            NSApp.setActivationPolicy(.regular)
        }
        
        Logger.log("Dock visibility updated, hideFromDock: \(hideFromDock)", level: .info)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.log("Application will terminate", level: .info)
        
        // Unregister hotkeys
        unregisterGlobalHotkeys()
    }
    
    // MARK: - UI Setup
    
    /// Requests accessibility permissions if needed
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            Logger.log("Requesting accessibility permissions...", level: .info)
            
            // Show a dialog explaining why accessibility permissions are needed
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Table Manager needs accessibility permissions to detect and arrange windows. Please grant access in the System Preferences dialog that appears."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            Logger.log("Accessibility permissions already granted", level: .info)
        }
    }
    
    /// Sets up notification observers
    private func setupNotificationObservers() {
        // Observe notifications for menu bar visibility toggle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarToggle),
            name: Constants.Notifications.toggleMenuBarItem,
            object: nil
        )
        
        // Observe notifications for configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationsChanged),
            name: Constants.Notifications.configurationsChanged,
            object: nil
        )
        
        // Observe notifications for Dock visibility toggle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDockVisibilityToggle),
            name: Constants.Notifications.toggleDockVisibility,
            object: nil
        )
    }
    
    // MARK: - Status Bar
    
    /// Sets up the status bar menu item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Table Manager")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        updateStatusMenu()
    }
    
    /// Updates the status bar menu
    private func updateStatusMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Table Manager", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Add configurations submenu
        let configurationsMenu = NSMenu()
        
        // Add each configuration
        for config in mainViewModel.configurations {
            let item = NSMenuItem(title: config.name, action: #selector(activateConfiguration(_:)), keyEquivalent: "")
            item.representedObject = config.id
            
            // Add checkmark if active
            if mainViewModel.activeConfigurationID == config.id {
                item.state = .on
            }
            
            configurationsMenu.addItem(item)
        }
        
        // Add menu item for no configurations
        if mainViewModel.configurations.isEmpty {
            let item = NSMenuItem(title: "No Configurations", action: nil, keyEquivalent: "")
            item.isEnabled = false
            configurationsMenu.addItem(item)
        }
        
        let configurationsItem = NSMenuItem(title: "Configurations", action: nil, keyEquivalent: "")
        configurationsItem.submenu = configurationsMenu
        menu.addItem(configurationsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Capture Layout...", action: #selector(captureLayout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Select Window...", action: #selector(selectWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Hotkeys
    
    /// Registers global hotkeys
    private func registerGlobalHotkeys() {
        // Unregister existing hotkeys first
        unregisterGlobalHotkeys()
        
        // Get hotkey strings from UserDefaults
        let captureHotkey = UserDefaults.standard.string(forKey: "captureHotkey") ?? "⌥⌘C"
        let selectHotkey = UserDefaults.standard.string(forKey: "selectHotkey") ?? "⌥⌘S"
        
        // Register hotkeys
        registerHotkey(hotkeyString: captureHotkey, id: 1, selector: #selector(captureLayout))
        registerHotkey(hotkeyString: selectHotkey, id: 2, selector: #selector(selectWindow))
    }
    
    /// Регистрирует глобальную горячую клавишу
    private func registerHotkey(hotkeyString: String, id: Int, selector: Selector) {
        // Парсим строку горячей клавиши
        var modifiers: UInt32 = 0
        var keyCode: UInt32 = 0
        
        // Проверяем модификаторы
        if hotkeyString.contains("⌘") { modifiers |= UInt32(cmdKey) }
        if hotkeyString.contains("⌥") { modifiers |= UInt32(optionKey) }
        if hotkeyString.contains("⌃") { modifiers |= UInt32(controlKey) }
        if hotkeyString.contains("⇧") { modifiers |= UInt32(shiftKey) }
        
        // Получаем символ
        let lastChar = hotkeyString.last.map(String.init) ?? ""
        
        // Безопасное получение кода клавиши через словарь
        let keyMap: [String: UInt32] = [
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34,
            "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12,
            "R": 15, "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
            "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96, "F6": 97, "F7": 98,
            "F8": 100, "F9": 101, "F10": 109, "F11": 103, "F12": 111,
            "Space": 49, "Return": 36, "←": 123, "→": 124, "↑": 126, "↓": 125
        ]
        
        // Безопасное получение кода клавиши
        if let code = keyMap[lastChar.uppercased()] {
            keyCode = code
        } else if let function = keyMap.keys.first(where: { hotkeyString.contains($0) }) {
            keyCode = keyMap[function] ?? 0
        }
        
        // Если не смогли определить код клавиши, логируем ошибку и выходим
        if keyCode == 0 && !lastChar.isEmpty {
            Logger.log("Unable to map key for hotkey: \(hotkeyString)", level: .error)
            return
        }
        
        // Создаем ID для горячей клавиши
        var hotKeyID = EventHotKeyID()
        
        // Безопасное создание сигнатуры
        let signature = "TblM"
        hotKeyID.signature = OSType(signature.utf8.reduce(0) { ($0 << 8) + UInt32($1) })
        hotKeyID.id = UInt32(id)
        
        // Сохраняем ID горячей клавиши
        hotkeyIDs.append(hotKeyID)
        
        // Регистрируем горячую клавишу
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        // Сохраняем ссылку, если успешно
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
            Logger.log("Registered hotkey: \(hotkeyString)", level: .info)
            
            // Устанавливаем обработчик событий, если это первая горячая клавиша
            if hotKeyRefs.count == 1 {
                installEventHandler()
            }
        } else {
            Logger.log("Failed to register hotkey: \(hotkeyString), error: \(status)", level: .error)
        }
    }
    
    /// Installs the event handler for hotkeys
    private func installEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let appEventTarget = GetApplicationEventTarget()
        
        // Install event handler
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            appEventTarget,
            { (_, event, userData) -> OSStatus in
                let selfPointer = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
                return selfPointer.handleHotKeyEvent(event)
            },
            1,
            &eventType,
            selfPointer,
            nil
        )
    }
    
    /// Handles hotkey events
    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        if status == noErr {
            // Dispatch based on hotkey ID
            switch hotKeyID.id {
            case 1:
                DispatchQueue.main.async { [weak self] in
                    self?.captureLayout()
                }
            case 2:
                DispatchQueue.main.async { [weak self] in
                    self?.selectWindow()
                }
            default:
                break
            }
        }
        
        return status
    }
    
    /// Unregisters all global hotkeys
    private func unregisterGlobalHotkeys() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        
        hotKeyRefs.removeAll()
        hotkeyIDs.removeAll()
    }
    
    // MARK: - Actions
    
    /// Handles status bar button click
    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button else { return }
        
        // Show the menu
        if let menu = statusItem?.menu {
            button.highlight(true)
            let position = NSPoint(x: button.frame.origin.x, y: button.frame.origin.y - 5)
            menu.popUp(positioning: nil, at: position, in: button)
        }
    }
    
    /// Shows the main window
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Activates a configuration
    @objc private func activateConfiguration(_ sender: NSMenuItem) {
        guard let configID = sender.representedObject as? String else {
            return
        }
        
        // Activate the configuration
        mainViewModel.activateConfiguration(configID)
        Logger.log("Activating configuration: \(configID)", level: .info)
        
        // Update menu to show checkmark
        updateStatusMenu()
    }
    
    /// Starts layout capture mode
    @objc private func captureLayout() {
        // Show the main window and start capture mode
        showMainWindow()
        
        // Start the capture mode
        mainViewModel.startCaptureMode()
        Logger.log("Starting layout capture mode", level: .info)
    }
    
    /// Opens window picker
    @objc private func selectWindow() {
        // Show the main window and open window picker
        showMainWindow()
        
        // Open window picker by posting a notification that MainView will observe
        NotificationCenter.default.post(name: NSNotification.Name("ShowWindowPicker"), object: nil)
        Logger.log("Opening window picker", level: .info)
    }
    
    /// Shows preferences
    @objc private func showPreferences() {
        // Show the main window and open preferences
        showMainWindow()
        
        // Open preferences by posting a notification that MainView will observe
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
        Logger.log("Opening preferences", level: .info)
    }
    
    // MARK: - Notification Handlers
    
    /// Handles menu bar visibility toggle
    @objc private func handleMenuBarToggle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let visible = userInfo["visible"] as? Bool else {
            return
        }
        
        if visible {
            if statusItem == nil {
                setupStatusItem()
            }
        } else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }
    
    /// Handles configuration changes
    @objc private func handleConfigurationsChanged(_ notification: Notification) {
        // Update the status menu when configurations change
        updateStatusMenu()
    }
    
    /// Handles Dock visibility toggle
    @objc private func handleDockVisibilityToggle(_ notification: Notification) {
        updateDockVisibility()
    }
}
