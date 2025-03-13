//
//  ConfigurationManager.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import Combine
import Cocoa

/// Manages configurations for window layouts and window types
class ConfigurationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Available configurations
    @Published private(set) var configurations: [Configuration] = []
    
    /// Currently active configuration
    @Published private(set) var activeConfiguration: Configuration?
    
    /// Available window types
    @Published private(set) var windowTypes: [WindowType] = []
    
    // MARK: - Private Properties
    
    /// Path for saving configurations
    private let configPath: URL
    
    /// Path for saving window types
    private let windowTypesPath: URL
    
    /// Auto-activation timer
    private var autoActivationTimer: Timer?
    
    /// Window manager for window detection
    private let windowManager: WindowManager
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // Get application support directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("TableManager")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        // Set file paths
        configPath = appDir.appendingPathComponent("configurations.json")
        windowTypesPath = appDir.appendingPathComponent("windowTypes.json")
        
        // Load saved data
        loadWindowTypes()
        loadConfigurations()
        
        // Start auto-activation if enabled
        startAutoActivation()
        
        // Setup auto-save
        setupAutoSave()
    }
    
    // MARK: - Public Methods
    
    /// Adds a new configuration
    /// - Parameter configuration: Configuration to add
    func addConfiguration(_ configuration: Configuration) {
        // Ensure unique ID
        var newConfig = configuration
        if configurations.contains(where: { $0.id == configuration.id }) {
            newConfig.id = UUID().uuidString
        }
        
        configurations.append(newConfig)
        saveConfigurations()
    }
    
    /// Updates an existing configuration
    /// - Parameter configuration: Configuration to update
    func updateConfiguration(_ configuration: Configuration) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            configurations[index] = configuration
            saveConfigurations()
            
            // Update active configuration if needed
            if activeConfiguration?.id == configuration.id {
                activeConfiguration = configuration
            }
        }
    }
    
    /// Removes a configuration
    /// - Parameter id: ID of configuration to remove
    func removeConfiguration(id: String) {
        configurations.removeAll { $0.id == id }
        saveConfigurations()
        
        // Clear active configuration if it was removed
        if activeConfiguration?.id == id {
            activeConfiguration = nil
        }
    }
    
    /// Activates a configuration
    /// - Parameter id: ID of configuration to activate
    func activateConfiguration(id: String) {
        guard let configuration = configurations.first(where: { $0.id == id }) else {
            Logger.log("Configuration not found: \(id)", level: .error)
            return
        }
        
        activeConfiguration = configuration
        applyActiveConfiguration()
    }
    
    /// Adds a new window type
    /// - Parameter windowType: Window type to add
    func addWindowType(_ windowType: WindowType) {
        // Ensure unique ID
        var newType = windowType
        if windowTypes.contains(where: { $0.id == windowType.id }) {
            newType.id = UUID().uuidString
        }
        
        windowTypes.append(newType)
        saveWindowTypes()
    }
    
    /// Updates an existing window type
    /// - Parameter windowType: Window type to update
    func updateWindowType(_ windowType: WindowType) {
        if let index = windowTypes.firstIndex(where: { $0.id == windowType.id }) {
            windowTypes[index] = windowType
            saveWindowTypes()
        }
    }
    
    /// Removes a window type
    /// - Parameter id: ID of window type to remove
    func removeWindowType(id: String) {
        windowTypes.removeAll { $0.id == id }
        saveWindowTypes()
    }
    
    /// Восстанавливает данные из резервной копии
    func restoreFromBackup() -> Bool {
        let fileManager = FileManager.default
        let configBackupPath = configPath.deletingPathExtension().appendingPathExtension("json.bak")
        let windowTypesBackupPath = windowTypesPath.deletingPathExtension().appendingPathExtension("json.bak")
        
        var success = false
        
        do {
            if fileManager.fileExists(atPath: configBackupPath.path) {
                if fileManager.fileExists(atPath: configPath.path) {
                    try fileManager.removeItem(at: configPath)
                }
                try fileManager.copyItem(at: configBackupPath, to: configPath)
                success = true
            }
            
            if fileManager.fileExists(atPath: windowTypesBackupPath.path) {
                if fileManager.fileExists(atPath: windowTypesPath.path) {
                    try fileManager.removeItem(at: windowTypesPath)
                }
                try fileManager.copyItem(at: windowTypesBackupPath, to: windowTypesPath)
                success = true
            }
            
            if success {
                // Загружаем восстановленные данные
                loadWindowTypes()
                loadConfigurations()
                Logger.log("Successfully restored from backup", level: .info)
            }
        } catch {
            Logger.log("Failed to restore from backup: \(error)", level: .error)
            success = false
        }
        
        return success
    }
    
    /// Creates a new configuration from the current window positions
    /// - Parameters:
    ///   - name: Name for the new configuration
    ///   - layoutEngine: Layout engine to use for capturing
    func captureCurrentLayout(name: String, layoutEngine: LayoutEngine) -> Configuration {
        // Capture current layout
        let capturedLayout = layoutEngine.captureCurrentLayout()
        
        // Optimize the layout
        let optimizedLayout = layoutEngine.optimizeCapturedLayout(capturedLayout)
        
        // Create a new configuration
        let configuration = Configuration(
            id: UUID().uuidString,
            name: name,
            layout: optimizedLayout,
            autoActivation: nil
        )
        
        return configuration
    }
    
    // MARK: - Private Methods
    
    /// Таймер автосохранения
    private var autoSaveTimer: Timer?

    /// Настраивает автосохранение
    private func setupAutoSave() {
        autoSaveTimer?.invalidate()
        
        // Автосохранение каждые 5 минут
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveConfigurations()
            self?.saveWindowTypes()
        }
    }

    /// Создает резервную копию перед сохранением
    private func backupBeforeSave() {
        let fileManager = FileManager.default
        let configBackupPath = configPath.deletingPathExtension().appendingPathExtension("json.bak")
        let windowTypesBackupPath = windowTypesPath.deletingPathExtension().appendingPathExtension("json.bak")
        
        do {
            if fileManager.fileExists(atPath: configPath.path) {
                if fileManager.fileExists(atPath: configBackupPath.path) {
                    try fileManager.removeItem(at: configBackupPath)
                }
                try fileManager.copyItem(at: configPath, to: configBackupPath)
            }
            
            if fileManager.fileExists(atPath: windowTypesPath.path) {
                if fileManager.fileExists(atPath: windowTypesBackupPath.path) {
                    try fileManager.removeItem(at: windowTypesBackupPath)
                }
                try fileManager.copyItem(at: windowTypesPath, to: windowTypesBackupPath)
            }
        } catch {
            Logger.log("Failed to create backup: \(error)", level: .error)
        }
    }

    /// Загружает сохраненные конфигурации
    private func loadConfigurations() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                if FileManager.default.fileExists(atPath: self.configPath.path) {
                    let data = try Data(contentsOf: self.configPath)
                    let loadedConfigs = try JSONDecoder().decode([Configuration].self, from: data)
                    
                    // Обновляем данные на главной очереди
                    DispatchQueue.main.async {
                        self.configurations = loadedConfigs
                        Logger.log("Loaded \(loadedConfigs.count) configurations", level: .info)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Logger.log("Failed to load configurations: \(error)", level: .error)
                }
            }
        }
    }
    
    /// Сохраняет конфигурации
    private func saveConfigurations() {
        // Сохраняем копию данных для обработки в фоновом потоке
        let configurationsToSave = self.configurations
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try JSONEncoder().encode(configurationsToSave)
                try data.write(to: self.configPath)
                
                DispatchQueue.main.async {
                    Logger.log("Saved \(configurationsToSave.count) configurations", level: .info)
                }
            } catch {
                DispatchQueue.main.async {
                    Logger.log("Failed to save configurations: \(error)", level: .error)
                }
            }
        }
    }
    
    /// Loads saved window types
    private func loadWindowTypes() {
        do {
            if FileManager.default.fileExists(atPath: windowTypesPath.path) {
                let data = try Data(contentsOf: windowTypesPath)
                windowTypes = try JSONDecoder().decode([WindowType].self, from: data)
                Logger.log("Loaded \(windowTypes.count) window types", level: .info)
            } else {
                // Create default window types if none exist
                createDefaultWindowTypes()
            }
        } catch {
            Logger.log("Failed to load window types: \(error)", level: .error)
            // Create default window types on error
            createDefaultWindowTypes()
        }
    }
    
    /// Saves window types
    private func saveWindowTypes() {
        do {
            let data = try JSONEncoder().encode(windowTypes)
            try data.write(to: windowTypesPath)
            Logger.log("Saved \(windowTypes.count) window types", level: .info)
        } catch {
            Logger.log("Failed to save window types: \(error)", level: .error)
        }
    }
    
    /// Creates default window types for common poker clients
    private func createDefaultWindowTypes() {
        windowTypes = [
            WindowType(
                id: UUID().uuidString,
                name: "PokerStars Table",
                titlePattern: "*Hold'em*",
                classPattern: "com.pokerstars.PokerStarsApp",
                enabled: true
            ),
            WindowType(
                id: UUID().uuidString,
                name: "PartyPoker Table",
                titlePattern: "*Party Poker*",
                classPattern: "com.partypoker.app",
                enabled: true
            ),
            WindowType(
                id: UUID().uuidString,
                name: "888poker Table",
                titlePattern: "*888poker*",
                classPattern: "com.888poker.app",
                enabled: true
            )
        ]
        saveWindowTypes()
    }
    
    /// Starts auto-activation timer
    private func startAutoActivation() {
        autoActivationTimer?.invalidate()
        
        // Check every 5 seconds
        autoActivationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAutoActivation()
        }
    }
    
    /// Checks if any configuration should be auto-activated
    private func checkAutoActivation() {
        // Skip if a configuration is already active
        guard activeConfiguration == nil else { return }
        
        // Get configurations with auto-activation
        let autoConfigs = configurations.filter { $0.autoActivation != nil }
        
        for config in autoConfigs {
            if let autoActivation = config.autoActivation, checkAutoActivationCondition(autoActivation) {
                Logger.log("Auto-activating configuration: \(config.name)", level: .info)
                activeConfiguration = config
                applyActiveConfiguration()
                break
            }
        }
    }
    
    /// Checks if an auto-activation condition is met
    /// - Parameter condition: Condition to check
    /// - Returns: True if condition is met
    private func checkAutoActivationCondition(_ condition: AutoActivationCondition) -> Bool {
        switch condition {
        case .windowCount(let count):
            return windowManager.detectedWindows.count == count
            
        case .windowTypeCount(let typeCounts):
            // Group detected windows by type
            let windowsByType = Dictionary(grouping: windowManager.detectedWindows) { $0.type.id }
            
            // Check if all type counts match
            for (typeID, requiredCount) in typeCounts {
                let actualCount = windowsByType[typeID]?.count ?? 0
                if actualCount != requiredCount {
                    return false
                }
            }
            return true
        }
    }
    
    /// Applies the currently active configuration
    private func applyActiveConfiguration() {
        guard let config = activeConfiguration else { return }
        
        // Start monitoring for window types used in this configuration
        let requiredWindowTypes = windowTypes.filter { type in
            type.enabled
        }
        
        windowManager.startDetection(windowTypes: requiredWindowTypes)
        
        // Apply layout after a short delay to allow window detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.windowManager.applyLayout(config.layout)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for window layout and auto-activation
struct Configuration: Identifiable, Codable {
    var id: String
    var name: String
    var layout: Layout
    var autoActivation: AutoActivationCondition?
}

/// Condition for automatic activation of a configuration
enum AutoActivationCondition: Codable {
    case windowCount(Int)                    // Activate when exact number of windows detected
    case windowTypeCount([String: Int])      // Activate when specific counts of window types detected
    
    // Custom coding for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, count, typeCounts
    }
    
    enum AutoActivationType: String, Codable {
        case windowCount
        case windowTypeCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(AutoActivationType.self, forKey: .type)
        
        switch type {
        case .windowCount:
            let count = try container.decode(Int.self, forKey: .count)
            self = .windowCount(count)
        case .windowTypeCount:
            let typeCounts = try container.decode([String: Int].self, forKey: .typeCounts)
            self = .windowTypeCount(typeCounts)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .windowCount(let count):
            try container.encode(AutoActivationType.windowCount, forKey: .type)
            try container.encode(count, forKey: .count)
        case .windowTypeCount(let typeCounts):
            try container.encode(AutoActivationType.windowTypeCount, forKey: .type)
            try container.encode(typeCounts, forKey: .typeCounts)
        }
    }
}
