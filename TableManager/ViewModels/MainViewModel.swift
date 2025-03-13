//
//  MainViewModel.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import Combine
import SwiftUI

/// Main view model for the application
class MainViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current application state
    @Published var appState: AppState = .idle
    
    /// Window manager status message
    @Published var statusMessage: String = "Ready"
    
    /// Available configurations
    @Published var configurations: [Configuration] = []
    
    /// Currently active configuration
    @Published var activeConfigurationID: String?
    
    /// Currently detected windows
    @Published var detectedWindows: [ManagedWindow] = []
    
    /// Whether layout capture mode is active
    @Published var isCaptureModeActive: Bool = false
    
    /// Captured layout (when in capture mode)
    @Published var capturedLayout: Layout?
    
    /// Selected view in sidebar
    @Published var selectedSidebarItem: MainView.SidebarItem = .configurations
    
    /// Selected configuration index
    @Published var selectedConfigurationIndex: Int?
    
    /// Whether settings view is shown
    @Published var showingSettings: Bool = false
    
    /// Whether window picker is shown
    @Published var showingWindowPicker: Bool = false
    
    /// Whether new configuration sheet is shown
    @Published var showingNewConfigSheet: Bool = false
    
    /// New configuration name
    @Published var newConfigName: String = "New Configuration"
    
    /// Last error message
    @Published var lastErrorMessage: String?
    
    /// Whether to show error alert
    @Published var showingErrorAlert: Bool = false
    
    // MARK: - Dependencies
    
    /// Window manager for window detection and manipulation
    let windowManager: WindowManager
    
    /// Layout engine for layout creation and manipulation
    let layoutEngine: LayoutEngine
    
    /// Configuration manager for configuration storage and retrieval
    let configManager: ConfigurationManager
    
    // MARK: - Private Properties
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Last capture timestamp
    private var lastCaptureTime: Date = Date()
    
    /// Debounce timer for status updates
    private var statusUpdateTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Initialize dependencies
        windowManager = WindowManager()
        layoutEngine = LayoutEngine(windowManager: windowManager)
        configManager = ConfigurationManager(windowManager: windowManager)
        
        // Set up subscriptions
        setupSubscriptions()
        
        // Load initial data
        loadData()
        
        Logger.log("MainViewModel initialized", level: .info)
    }
    
    // MARK: - Public Methods
    
    /// Loads initial data
    func loadData() {
        // Update configurations list
        configurations = configManager.configurations
        
        // Check if there's an active configuration
        if let activeConfig = configManager.activeConfiguration {
            activeConfigurationID = activeConfig.id
            
            // Find the index in our array
            selectedConfigurationIndex = configurations.firstIndex { $0.id == activeConfig.id }
        }
        
        Logger.log("Loaded \(configurations.count) configurations", level: .info)
    }
    
    /// Activates a configuration
    /// - Parameter configID: Configuration ID to activate
    func activateConfiguration(_ configID: String) {
        // Update UI state
        activeConfigurationID = configID
        selectedConfigurationIndex = configurations.firstIndex { $0.id == configID }
        selectedSidebarItem = .configurations
        
        // Activate in configuration manager
        configManager.activateConfiguration(id: configID)
        
        // Update status message
        if let config = configurations.first(where: { $0.id == configID }) {
            updateStatus("Activated configuration: \(config.name)")
        }
        
        // Post notification for menu updates
        NotificationCenter.default.post(name: NSNotification.Name("ConfigurationsChanged"), object: nil)
        
        Logger.log("Activated configuration: \(configID)", level: .info)
    }
    
    /// Creates a new configuration
    /// - Parameter name: Name for the new configuration
    func createConfiguration(name: String) {
        // Create a basic 2x2 grid layout for the main display
        let layout = layoutEngine.createGridLayout(
            rows: 2,
            columns: 2,
            displayID: CGMainDisplayID()
        )
        
        // Create and add the configuration
        let newConfig = Configuration(
            id: UUID().uuidString,
            name: name,
            layout: layout,
            autoActivation: nil
        )
        
        configManager.addConfiguration(newConfig)
        
        // Update status
        updateStatus("Created new configuration: \(name)")
        
        // Select the new configuration
        selectedConfigurationIndex = configurations.count - 1
        
        // Post notification for menu updates
        NotificationCenter.default.post(name: NSNotification.Name("ConfigurationsChanged"), object: nil)
        
        Logger.log("Created new configuration: \(name)", level: .info)
    }
    
    /// Starts layout capture mode
    func startCaptureMode() {
        isCaptureModeActive = true
        appState = .capturing
        lastCaptureTime = Date()
        
        // Make sure window detection is active with all window types
        windowManager.startDetection(windowTypes: configManager.windowTypes.filter { $0.enabled })
        
        // Update status
        updateStatus("Layout capture mode active. Detecting windows...")
        
        Logger.log("Started layout capture mode", level: .info)
    }
    
    /// Captures the current layout
    /// - Parameter name: Name for the captured layout
    func captureCurrentLayout(name: String) {
        // Capture the current layout
        let config = configManager.captureCurrentLayout(name: name, layoutEngine: layoutEngine)
        
        // Add it to configurations
        configManager.addConfiguration(config)
        
        // Update local list
        configurations = configManager.configurations
        
        // Exit capture mode
        isCaptureModeActive = false
        capturedLayout = nil
        appState = .idle
        
        // Update status
        updateStatus("Captured layout: \(name) with \(config.layout.slots.count) slots")
        
        // Post notification for menu updates
        NotificationCenter.default.post(name: NSNotification.Name("ConfigurationsChanged"), object: nil)
        
        Logger.log("Captured layout: \(name) with \(config.layout.slots.count) slots", level: .info)
    }
    
    /// Cancels layout capture mode
    func cancelCaptureMode() {
        isCaptureModeActive = false
        capturedLayout = nil
        appState = .idle
        
        // Update status
        updateStatus("Layout capture canceled")
        
        Logger.log("Canceled layout capture mode", level: .info)
    }
    
    /// Adds a new window type
    /// - Parameter windowType: Window type to add
    func addWindowType(_ windowType: WindowType) {
        configManager.addWindowType(windowType)
        
        // Update status
        updateStatus("Added window type: \(windowType.name)")
        
        // Refresh window detection if active
        if appState == .monitoring || appState == .detecting {
            windowManager.refreshDetection()
        }
        
        Logger.log("Added window type: \(windowType.name)", level: .info)
    }
    
    /// Updates an existing window type
    /// - Parameter windowType: Window type to update
    func updateWindowType(_ windowType: WindowType) {
        configManager.updateWindowType(windowType)
        
        // Update status
        updateStatus("Updated window type: \(windowType.name)")
        
        // Refresh window detection if active
        if appState == .monitoring || appState == .detecting {
            windowManager.refreshDetection()
        }
        
        Logger.log("Updated window type: \(windowType.name)", level: .info)
    }
    
    /// Creates a new window type from a window
    /// - Parameter info: Window information
    /// - Returns: New window type
    func createWindowTypeFromInfo(_ info: WindowInfo) -> WindowType {
        // Create a window selector view model
        let selectorViewModel = WindowSelectorViewModel(windowManager: windowManager)
        
        // Generate the name using helper functions
        let name = generateWindowTypeName(from: info)
        let titlePattern = createTitlePattern(from: info.title)
        let classPattern = createClassPattern(from: info.windowClass)
        
        // Create the window type
        let windowType = WindowType(
            id: UUID().uuidString,
            name: name,
            titlePattern: titlePattern,
            classPattern: classPattern,
            enabled: true
        )
        
        Logger.log("Created window type from info: \(windowType.name), pattern: \(windowType.titlePattern)", level: .info)
        
        return windowType
    }
    
    /// Starts window detection
    func startWindowDetection() {
        // Get enabled window types
        let enabledTypes = configManager.windowTypes.filter { $0.enabled }
        
        if enabledTypes.isEmpty {
            showError("No enabled window types found. Please create and enable window types first.")
            return
        }
        
        // Start detection
        windowManager.startDetection(windowTypes: enabledTypes)
        
        // Update status
        updateStatus("Started window detection with \(enabledTypes.count) window types")
        
        Logger.log("Started window detection with \(enabledTypes.count) window types", level: .info)
    }
    
    /// Stops window detection
    func stopWindowDetection() {
        windowManager.stopDetection()
        
        // Update status
        updateStatus("Stopped window detection")
        
        Logger.log("Stopped window detection", level: .info)
    }
    
    /// Handles sidebar item selection
    /// - Parameter item: Selected sidebar item
    func selectSidebarItem(_ item: MainView.SidebarItem) {
        selectedSidebarItem = item
        
        // Update based on selection
        switch item {
        case .configurations:
            if configurations.isEmpty {
                showingNewConfigSheet = true
            }
        case .windowTypes:
            // Nothing specific here
            break
        case .settings:
            showingSettings = true
        }
    }
    
    /// Shows an error message
    /// - Parameter message: Error message to show
    func showError(_ message: String) {
        lastErrorMessage = message
        showingErrorAlert = true
        
        NotificationManager.shared.show(message, type: .error)
    }
    
    // MARK: - Private Methods
    
    /// Sets up Combine subscriptions
    private func setupSubscriptions() {
        // Subscribe to window manager detected windows
        windowManager.$detectedWindows
            .sink { [weak self] windows in
                self?.detectedWindows = windows
                
                // Update status message
                if windows.isEmpty {
                    self?.updateStatus("No windows detected")
                } else {
                    // Group windows by type
                    let windowsByType = Dictionary(grouping: windows) { $0.type.name }
                    let windowSummary = windowsByType.map { "\($0.value.count) \($0.key)" }.joined(separator: ", ")
                    self?.updateStatus("Detected: \(windowSummary)")
                }
                
                // Update captured layout if in capture mode
                if self?.isCaptureModeActive == true {
                    // Only update the captured layout if it's been at least 0.5 seconds since the last capture
                    // to avoid flickering during window detection
                    let now = Date()
                    if let lastCapture = self?.lastCaptureTime, now.timeIntervalSince(lastCapture) > 0.5 {
                        self?.capturedLayout = self?.layoutEngine.captureCurrentLayout()
                        self?.lastCaptureTime = now
                    }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to window manager status
        windowManager.$status
            .sink { [weak self] status in
                switch status {
                case .idle:
                    self?.appState = .idle
                case .detecting:
                    self?.appState = .detecting
                case .monitoring:
                    self?.appState = .monitoring
                case .arranging:
                    self?.appState = .arranging
                case .noWindows:
                    self?.appState = .monitoring
                    self?.updateStatus("No windows detected")
                case .error(let message):
                    self?.appState = .error
                    self?.updateStatus("Error: \(message)")
                    self?.showError(message)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to configuration manager configurations
        configManager.$configurations
            .sink { [weak self] configurations in
                self?.configurations = configurations
            }
            .store(in: &cancellables)
        
        // Subscribe to active configuration
        configManager.$activeConfiguration
            .sink { [weak self] configuration in
                self?.activeConfigurationID = configuration?.id
                
                // Update selected index if we have an active configuration
                if let activeID = configuration?.id {
                    self?.selectedConfigurationIndex = self?.configurations.firstIndex { $0.id == activeID }
                }
            }
            .store(in: &cancellables)
        
        // Observe notifications for showing window picker
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowWindowPicker"))
            .sink { [weak self] _ in
                self?.showingWindowPicker = true
            }
            .store(in: &cancellables)
        
        // Observe notifications for showing settings
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettings"))
            .sink { [weak self] _ in
                self?.showingSettings = true
                self?.selectedSidebarItem = .settings
            }
            .store(in: &cancellables)
    }
    
    /// Updates the status message with debouncing
    private func updateStatus(_ message: String) {
        // Cancel any pending updates
        statusUpdateTimer?.invalidate()
        
        // Schedule update with a short delay to avoid rapid changes
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.statusMessage = message
        }
    }
    
    // MARK: - Window Type Helper Methods
    
    /// Generates a name for a window type based on window info
    private func generateWindowTypeName(from windowInfo: WindowInfo) -> String {
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
        if windowInfo.windowClass.lowercased().contains("poker") {
            if windowInfo.windowClass.lowercased().contains("pokerstars") {
                appName = "PokerStars"
            } else if windowInfo.windowClass.lowercased().contains("partypoker") {
                appName = "PartyPoker"
            } else if windowInfo.windowClass.lowercased().contains("888poker") {
                appName = "888poker"
            }
        }
        
        // Shorten the window title if it's too long
        var shortTitle = windowInfo.title
        if shortTitle.count > 20 {
            shortTitle = String(shortTitle.prefix(17)) + "..."
        }
        
        return "\(appName) - \(shortTitle)"
    }
    
    /// Creates a title pattern with wildcards from a window title
    private func createTitlePattern(from title: String) -> String {
        // For poker tables, check for common patterns
        let lowercaseTitle = title.lowercased()
        
        if lowercaseTitle.contains("hold'em") || lowercaseTitle.contains("holdem") {
            return "*Hold'em*"
        } else if lowercaseTitle.contains("omaha") {
            return "*Omaha*"
        } else if lowercaseTitle.contains("table") {
            return "*Table*"
        } else if lowercaseTitle.contains("tournament") {
            return "*Tournament*"
        }
        
        // Default approach: add wildcards before and after
        return "*\(title)*"
    }
    
    /// Creates a class pattern for a window class
    private func createClassPattern(from windowClass: String) -> String {
        // For bundle IDs, use the exact class
        if windowClass.contains(".") {
            return windowClass
        }
        
        // For other identifiers, add wildcards
        return "*\(windowClass)*"
    }
}

// MARK: - Supporting Types

/// Application state
enum AppState {
    case idle
    case detecting
    case monitoring
    case arranging
    case capturing
    case error
}
