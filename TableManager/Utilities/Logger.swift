//
//  Logger.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import os.log

/// Simple logging utility for the application
class Logger {
    /// Log levels for messages
    enum Level: String {
        case debug = "📘 DEBUG"
        case info = "📗 INFO"
        case warning = "📙 WARNING"
        case error = "📕 ERROR"
    }
    
    /// macOS system logger
    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.tablemanager", category: "TableManager")
    
    /// File URL for log file
    private static let logFileURL: URL = {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("TableManager")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        return appDir.appendingPathComponent("TableManager.log")
    }()
    
    /// Maximum log file size in bytes (5 MB)
    private static let maxLogSize: UInt64 = 5 * 1024 * 1024
    
    /// Whether to enable file logging
    private static var fileLoggingEnabled = true
    
    /// Whether to enable console logging
    private static var consoleLoggingEnabled = true
    
    /// Logs a message
    /// - Parameters:
    ///   - message: Message to log
    ///   - level: Log level
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    static func log(
        _ message: String,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"
        
        // Log to console if enabled
        if consoleLoggingEnabled {
            switch level {
            case .debug:
                os_log("%{public}@", log: osLog, type: .debug, logMessage)
            case .info:
                os_log("%{public}@", log: osLog, type: .info, logMessage)
            case .warning:
                os_log("%{public}@", log: osLog, type: .default, logMessage)
            case .error:
                os_log("%{public}@", log: osLog, type: .error, logMessage)
            }
            
            #if DEBUG
            print(logMessage)
            #endif
        }
        
        // Log to file if enabled
        if fileLoggingEnabled {
            logToFile(logMessage)
        }
    }
    
    /// Logs a message to the log file
    /// - Parameter message: Message to log
    private static func logToFile(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let logLine = "\(timestamp) \(message)\n"
        
        // Check log file size and rotate if needed
        rotateLogIfNeeded()
        
        // Write to log file
        if let data = logLine.data(using: .utf8) {
            do {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                defer {
                    fileHandle.closeFile()
                }
                
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } catch {
                // If file doesn't exist yet, create it
                try? logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    /// Rotates the log file if it exceeds the maximum size
    private static func rotateLogIfNeeded() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            if let fileSize = attributes[.size] as? UInt64, fileSize > maxLogSize {
                // Backup old log
                let backupURL = logFileURL.deletingPathExtension().appendingPathExtension("log.bak")
                _ = try? FileManager.default.removeItem(at: backupURL)
                try FileManager.default.moveItem(at: logFileURL, to: backupURL)
            }
        } catch {
            // File doesn't exist yet, no need to rotate
        }
    }
    
    /// Enables or disables file logging
    /// - Parameter enabled: Whether file logging should be enabled
    static func setFileLogging(enabled: Bool) {
        fileLoggingEnabled = enabled
    }
    
    /// Enables or disables console logging
    /// - Parameter enabled: Whether console logging should be enabled
    static func setConsoleLogging(enabled: Bool) {
        consoleLoggingEnabled = enabled
    }
}
