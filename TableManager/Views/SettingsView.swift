//
//  SettingsView.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI
import ServiceManagement

/// View for application settings
struct SettingsView: View {
    // MARK: - Properties
    
    /// Application settings stored in UserDefaults
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("autostartDetection") private var autostartDetection = true
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("showDebugLogs") private var showDebugLogs = false
    @AppStorage("detectionInterval") private var detectionInterval = 1.0
    @AppStorage("showConfirmations") private var showConfirmations = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("hideFromDock") private var hideFromDock = false
    
    /// Settings for activating windows on hover
    @AppStorage("enableHoverActivation") private var enableHoverActivation = false
    @AppStorage("hoverDelay") private var hoverDelay = 0.3 // 300 ms delay by default
    
    /// Config manager reference (passed from parent view)
    @State private var configManager: ConfigurationManager?
    
    /// Window manager reference (passed from parent view)
    @State private var windowManager: WindowManager?
    
    /// Hotkey for capturing layout
    @State private var captureHotkey = "⌥⌘C"
    
    /// Hotkey for window selection
    @State private var selectHotkey = "⌥⌘S"
    
    /// Show hotkey editor for capture
    @State private var showCaptureHotkeyEditor = false
    
    /// Show hotkey editor for select
    @State private var showSelectHotkeyEditor = false
    
    /// Show confirmation for reset
    @State private var showResetConfirmation = false
    
    /// Show import file picker
    @State private var showImportPicker = false
    
    /// Show export file picker
    @State private var showExportPicker = false
    
    /// Show success toast
    @State private var showSuccessToast = false
    
    /// Success message
    @State private var successMessage = ""
    
    // MARK: - Init
    
    init(configManager: ConfigurationManager? = nil, windowManager: WindowManager? = nil) {
        self._configManager = State(initialValue: configManager)
        self._windowManager = State(initialValue: windowManager)
        
        // Load hotkeys from UserDefaults
        let defaults = UserDefaults.standard
        if let captureKey = defaults.string(forKey: "captureHotkey") {
            self._captureHotkey = State(initialValue: captureKey)
        }
        if let selectKey = defaults.string(forKey: "selectHotkey") {
            self._selectHotkey = State(initialValue: selectKey)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title)
                    .padding(.bottom, 10)
                
                generalSettings
                
                Divider()
                
                detectionSettings
                
                Divider()
                
                windowActivationSettings
                
                Divider()
                
                hotkeySettings
                
                Divider()
                
                advancedSettings
                
                Divider()
                
                aboutSection
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color(.windowBackgroundColor))
        .onChange(of: startAtLogin) { newValue in
            setupLoginItem(enabled: newValue)
        }
        .onChange(of: showInMenuBar) { newValue in
            toggleMenuBarItem(visible: newValue)
        }
        .onChange(of: detectionInterval) { newValue in
            windowManager?.updateDetectionInterval(newValue)
        }
        .onChange(of: hideFromDock) { newValue in
            NotificationCenter.default.post(name: NSNotification.Name("ToggleDockVisibility"), object: nil)
            showSuccessToast = true
            successMessage = "Dock visibility changed. May require app restart for full effect."
        }
        .onChange(of: enableHoverActivation) { newValue in
            windowManager?.updateHoverSettings()
        }
        .onChange(of: hoverDelay) { newValue in
            windowManager?.updateHoverSettings()
        }
        .sheet(isPresented: $showCaptureHotkeyEditor) {
            HotkeyEditorView(hotkey: $captureHotkey, title: "Capture Layout Hotkey") { newHotkey in
                captureHotkey = newHotkey
                UserDefaults.standard.set(newHotkey, forKey: "captureHotkey")
                registerHotkeys()
                showSuccessToast = true
                successMessage = "Capture hotkey updated"
            }
        }
        .sheet(isPresented: $showSelectHotkeyEditor) {
            HotkeyEditorView(hotkey: $selectHotkey, title: "Select Window Hotkey") { newHotkey in
                selectHotkey = newHotkey
                UserDefaults.standard.set(newHotkey, forKey: "selectHotkey")
                registerHotkeys()
                showSuccessToast = true
                successMessage = "Select window hotkey updated"
            }
        }
        .alert("Reset All Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
                showSuccessToast = true
                successMessage = "All settings reset to defaults"
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .overlay(
            Group {
                if showSuccessToast {
                    VStack {
                        Spacer()
                        
                        Text(successMessage)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.controlBackgroundColor)))
                            .shadow(radius: 2)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom))
                            .onAppear {
                                // Auto-hide after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showSuccessToast = false
                                    }
                                }
                            }
                    }
                }
            }
        )
        .onAppear {
            // Update Logger settings
            Logger.setFileLogging(enabled: true)
            Logger.setConsoleLogging(enabled: showDebugLogs)
        }
        .onChange(of: showDebugLogs) { newValue in
            Logger.setConsoleLogging(enabled: newValue)
        }
    }
    
    // MARK: - View Components
    
    /// General application settings
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General")
                .font(.headline)
            
            Toggle("Start at login", isOn: $startAtLogin)
                .help("Automatically start Table Manager when you log in")
            
            Toggle("Show in menu bar", isOn: $showInMenuBar)
                .help("Show Table Manager icon in the macOS menu bar")
            
            Toggle("Hide from Dock", isOn: $hideFromDock)
                .help("Show only in menu bar and hide from Dock (requires app restart)")
            
            Toggle("Enable window animations", isOn: $enableAnimations)
                .help("Animate windows when applying layouts")
            
            Toggle("Show confirmation dialogs", isOn: $showConfirmations)
                .help("Show confirmation dialogs for destructive actions")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Window detection settings
    private var detectionSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Window Detection")
                .font(.headline)
            
            Toggle("Automatically start detection", isOn: $autostartDetection)
                .help("Start detecting poker windows when application launches")
            
            HStack {
                Text("Detection interval:")
                
                Slider(value: $detectionInterval, in: 0.2...5.0, step: 0.1)
                    .frame(width: 200)
                
                Text("\(detectionInterval, specifier: "%.1f") seconds")
                    .frame(width: 80, alignment: .trailing)
            }
            .help("How frequently to scan for new windows (lower values increase responsiveness but use more CPU)")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Window activation settings
    private var windowActivationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Window Activation")
                .font(.headline)
            
            Toggle("Activate windows on hover", isOn: $enableHoverActivation)
                .help("Windows will be activated (brought to front) when you hover over them")
            
            if enableHoverActivation {
                HStack {
                    Text("Hover delay:")
                    
                    Slider(value: $hoverDelay, in: 0.0...1.0, step: 0.1)
                        .frame(width: 200)
                    
                    Text("\(Int(hoverDelay * 1000)) ms")
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.leading)
                .help("Delay before window is activated after hovering")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Hotkey settings
    private var hotkeySettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hotkeys")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    Text("Capture layout:")
                        .gridColumnAlignment(.trailing)
                    
                    Button(captureHotkey) {
                        showCaptureHotkeyEditor = true
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 100)
                }
                
                GridRow {
                    Text("Select window:")
                        .gridColumnAlignment(.trailing)
                    
                    Button(selectHotkey) {
                        showSelectHotkeyEditor = true
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 100)
                }
            }
            
            Text("Click a hotkey to change it")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Advanced settings
    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Advanced")
                .font(.headline)
            
            Toggle("Show debug logs", isOn: $showDebugLogs)
                .help("Show detailed logs for debugging")
            
            HStack {
                Button("Export Configurations...") {
                    exportConfigurations()
                }
                .buttonStyle(.bordered)
                
                Button("Import Configurations...") {
                    importConfigurations()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Reset All Settings") {
                if showConfirmations {
                    showResetConfirmation = true
                } else {
                    resetSettings()
                    showSuccessToast = true
                    successMessage = "All settings reset to defaults"
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// About section
    private var aboutSection: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Table Manager")
                .font(.headline)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("© 2023 Table Manager")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link("View Documentation", destination: URL(string: "https://tablemanager.app/docs")!)
                .font(.caption)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Methods
    
    /// Sets up the login item
    private func setupLoginItem(enabled: Bool) {
        // Use SMAppService for macOS 13+, or legacy approach for older macOS
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            do {
                if enabled {
                    try appService.register()
                } else {
                    try appService.unregister()
                }
            } catch {
                Logger.log("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)", level: .error)
            }
        } else {
            // Legacy approach for older macOS versions - safely unwrap values
            guard let bundleURL = Bundle.main.bundleURL as CFURL? else { return }
            
            if let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() {
                if enabled {
                    // Add login item
                    LSSharedFileListInsertItemURL(
                        loginItemsRef,
                        kLSSharedFileListItemLast.takeRetainedValue(),
                        nil,
                        nil,
                        bundleURL,
                        nil,
                        nil
                    )
                } else {
                    // Remove login item
                    if let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)!.takeRetainedValue() as? [LSSharedFileListItem] {
                        for loginItem in loginItems {
                            if let propertyRef = LSSharedFileListItemCopyResolvedURL(loginItem, 0, nil) {
                                let itemURL = propertyRef.takeRetainedValue() as URL
                                if itemURL == bundleURL as URL {
                                    LSSharedFileListItemRemove(loginItemsRef, loginItem)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        
        Logger.log("Login item \(enabled ? "enabled" : "disabled")", level: .info)
    }
    
    /// Toggles the menu bar item
    private func toggleMenuBarItem(visible: Bool) {
        // This is handled by AppDelegate, we're just updating the preference
        // In a real app, we'd post a notification that AppDelegate would observe
        NotificationCenter.default.post(name: NSNotification.Name("ToggleMenuBarItem"), object: nil, userInfo: ["visible": visible])
        Logger.log("Menu bar item visibility set to: \(visible)", level: .info)
    }
    
    /// Registers global hotkeys
    private func registerHotkeys() {
        // In a real app, this would register system-wide hotkeys
        // We'd use Carbon hotkey API or a library like HotKey
        // For now, we just log the action
        Logger.log("Registering hotkeys - Capture: \(captureHotkey), Select: \(selectHotkey)", level: .info)
    }
    
    /// Exports configurations to a file
    private func exportConfigurations() {
        guard let configManager = configManager else {
            Logger.log("ConfigManager not available for export", level: .error)
            return
        }
        
        // Get configurations
        let configurations = configManager.configurations
        
        // Create a JSON representation
        do {
            let data = try JSONEncoder().encode(configurations)
            
            // Create a save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "TableManagerConfigurations.json"
            
            // Show the save panel
            savePanel.begin { result in
                if result == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                        Logger.log("Configurations exported to \(url.path)", level: .info)
                        
                        // Show success message
                        DispatchQueue.main.async {
                            showSuccessToast = true
                            successMessage = "Configurations exported successfully"
                        }
                    } catch {
                        Logger.log("Failed to write configurations: \(error.localizedDescription)", level: .error)
                    }
                }
            }
        } catch {
            Logger.log("Failed to encode configurations: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// Imports configurations from a file
    private func importConfigurations() {
        guard let configManager = configManager else {
            Logger.log("ConfigManager not available for import", level: .error)
            return
        }
        
        // Create an open panel
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        // Show the open panel
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let importedConfigurations = try JSONDecoder().decode([Configuration].self, from: data)
                    
                    // Add imported configurations
                    for config in importedConfigurations {
                        configManager.addConfiguration(config)
                    }
                    
                    Logger.log("Imported \(importedConfigurations.count) configurations", level: .info)
                    
                    // Show success message
                    DispatchQueue.main.async {
                        showSuccessToast = true
                        successMessage = "Imported \(importedConfigurations.count) configurations"
                    }
                } catch {
                    Logger.log("Failed to import configurations: \(error.localizedDescription)", level: .error)
                    
                    // Show error message (in a real app, we'd use a proper alert)
                    DispatchQueue.main.async {
                        showSuccessToast = true
                        successMessage = "Error: Failed to import configurations"
                    }
                }
            }
        }
    }
    
    /// Resets all settings to defaults
    private func resetSettings() {
        // Reset UserDefaults values
        startAtLogin = false
        autostartDetection = true
        showInMenuBar = true
        showDebugLogs = false
        detectionInterval = 1.0
        showConfirmations = true
        enableAnimations = true
        enableHoverActivation = false
        hoverDelay = 0.3
        
        // Reset hotkeys
        captureHotkey = "⌥⌘C"
        selectHotkey = "⌥⌘S"
        UserDefaults.standard.set(captureHotkey, forKey: "captureHotkey")
        UserDefaults.standard.set(selectHotkey, forKey: "selectHotkey")
        
        // Apply settings
        setupLoginItem(enabled: startAtLogin)
        toggleMenuBarItem(visible: showInMenuBar)
        windowManager?.updateDetectionInterval(detectionInterval)
        windowManager?.updateHoverSettings()
        Logger.setConsoleLogging(enabled: showDebugLogs)
        
        Logger.log("All settings reset to defaults", level: .info)
    }
}

/// View for editing hotkeys
struct HotkeyEditorView: View {
    /// Current hotkey binding
    @Binding var hotkey: String
    
    /// Title for the editor
    let title: String
    
    /// Callback when a hotkey is saved
    let onSave: (String) -> Void
    
    /// Selected modifier keys
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false
    
    /// Selected key
    @State private var selectedKey = ""
    
    /// Available keys for selection
    private let availableKeys = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
                               "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
                               "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                               "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
                               "←", "→", "↑", "↓", "Space", "Return"]
    
    /// Initializes the view and parses the current hotkey
    init(hotkey: Binding<String>, title: String, onSave: @escaping (String) -> Void) {
        self._hotkey = hotkey
        self.title = title
        self.onSave = onSave
        
        // Parse the current hotkey
        let currentHotkey = hotkey.wrappedValue
        
        // Initialize state variables based on current hotkey
        _command = State(initialValue: currentHotkey.contains("⌘"))
        _option = State(initialValue: currentHotkey.contains("⌥"))
        _control = State(initialValue: currentHotkey.contains("⌃"))
        _shift = State(initialValue: currentHotkey.contains("⇧"))
        
        // Extract the key part (last character or word)
        var key = ""
        if let lastChar = currentHotkey.last {
            key = String(lastChar)
        }
        
        // Check for function keys
        for fKey in ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"] {
            if currentHotkey.contains(fKey) {
                key = fKey
                break
            }
        }
        
        // Check for arrow keys and special keys
        if currentHotkey.contains("←") { key = "←" }
        else if currentHotkey.contains("→") { key = "→" }
        else if currentHotkey.contains("↑") { key = "↑" }
        else if currentHotkey.contains("↓") { key = "↓" }
        else if currentHotkey.contains("Space") { key = "Space" }
        else if currentHotkey.contains("Return") { key = "Return" }
        
        _selectedKey = State(initialValue: key)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            // Current hotkey
            Text("Current hotkey: \(formattedHotkey)")
                .font(.title)
                .padding()
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)))
            
            // Modifier keys
            HStack(spacing: 20) {
                Toggle("⌘ Command", isOn: $command)
                Toggle("⌥ Option", isOn: $option)
                Toggle("⌃ Control", isOn: $control)
                Toggle("⇧ Shift", isOn: $shift)
            }
            .padding()
            
            // Key picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Select a key:")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                    ForEach(availableKeys, id: \.self) { key in
                        Button(key) {
                            selectedKey = key
                        }
                        .padding(8)
                        .frame(minWidth: 40)
                        .background(selectedKey == key ? Color.accentColor : Color(.controlBackgroundColor))
                        .foregroundColor(selectedKey == key ? Color.white : Color.primary)
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
            
            // Error message if no modifiers or key selected
            if !command && !option && !control && !shift {
                Text("Please select at least one modifier key")
                    .foregroundColor(.red)
            }
            
            if selectedKey.isEmpty {
                Text("Please select a key")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    // Just close sheet
                }
                
                Spacer()
                
                Button("Save") {
                    // Update hotkey and save
                    hotkey = formattedHotkey
                    onSave(formattedHotkey)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isHotkeyValid)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .padding()
    }
    
    /// Formats the hotkey string
    private var formattedHotkey: String {
        var result = ""
        if control { result += "⌃" }
        if option { result += "⌥" }
        if shift { result += "⇧" }
        if command { result += "⌘" }
        result += selectedKey
        return result
    }
    
    /// Checks if the current hotkey is valid
    private var isHotkeyValid: Bool {
        // At least one modifier and a key must be selected
        return (command || option || control || shift) && !selectedKey.isEmpty
    }
}
