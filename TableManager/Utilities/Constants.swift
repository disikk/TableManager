//
//  Constants.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation

/// Константы, используемые в приложении
struct Constants {
    /// Имена уведомлений
    struct Notifications {
        static let showNewConfigSheet = Notification.Name("ShowNewConfigSheet")
        static let captureLayout = Notification.Name("CaptureLayout")
        static let showWindowPicker = Notification.Name("ShowWindowPicker")
        static let showSettings = Notification.Name("ShowSettings")
        static let toggleMenuBarItem = Notification.Name("ToggleMenuBarItem")
        static let configurationsChanged = Notification.Name("ConfigurationsChanged")
        static let toggleDockVisibility = Notification.Name("ToggleDockVisibility")
        static let windowActivated = Notification.Name("WindowActivated")
    }
    
    /// Ключи для UserDefaults
    struct UserDefaults {
        static let startAtLogin = "startAtLogin"
        static let autostartDetection = "autostartDetection"
        static let showInMenuBar = "showInMenuBar"
        static let showDebugLogs = "showDebugLogs"
        static let detectionInterval = "detectionInterval"
        static let showConfirmations = "showConfirmations"
        static let enableAnimations = "enableAnimations"
        static let hideFromDock = "hideFromDock"
        static let enableHoverActivation = "enableHoverActivation"
        static let hoverDelay = "hoverDelay"
        static let captureHotkey = "captureHotkey"
        static let selectHotkey = "selectHotkey"
    }
}

// Расширение для удобного доступа к уведомлениям
extension Notification.Name {
    static let windowActivated = Constants.Notifications.windowActivated
}
