//
//  WindowUtilities.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import Cocoa
import ApplicationServices

// Объявление приватного API метода для доступа к ID окна
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError {
    // Это внутренний вызов macOS API, который мы объявляем для использования
    let result = AXUIElementGetPid(element, windowID)
    return result
}

/// Утилиты для работы с окнами
struct WindowUtilities {
    /// Генерирует имя для типа окна на основе его параметров
    /// - Parameters:
    ///   - windowTitle: Заголовок окна
    ///   - windowClass: Класс окна
    /// - Returns: Сгенерированное имя
    static func generateWindowTypeName(from windowTitle: String, windowClass: String) -> String {
        // Получаем имя приложения из класса
        let appName = windowClass.components(separatedBy: ".").last ?? windowClass
        
        // Формируем имя типа окна
        var name = appName
        
        // Если заголовок окна содержит дополнительную информацию, добавляем её
        if !windowTitle.isEmpty && !windowTitle.lowercased().contains(appName.lowercased()) {
            // Берем первые 20 символов заголовка или меньше
            let titlePart = String(windowTitle.prefix(20))
            name += " - \(titlePart)"
        }
        
        // Если имя получилось слишком длинным, обрезаем его
        if name.count > 30 {
            name = String(name.prefix(27)) + "..."
        }
        
        return name
    }
    
    /// Безопасно активирует окно с обработкой ошибок доступности
    /// - Parameters:
    ///   - windowID: ID окна для активации
    ///   - pid: ID процесса окна
    /// - Returns: Успешность операции
    static func safeActivateWindow(windowID: CGWindowID, pid: pid_t) -> Bool {
        // Создаем элемент доступности для окна
        guard let app = AXUIElementCreateApplication(pid) else {
            Logger.log("Failed to create accessibility element for PID: \(pid)", level: .error)
            return false
        }
        
        // Получаем список окон приложения
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        
        guard result == .success, let windows = value as? [AXUIElement] else {
            Logger.log("Failed to get windows for app with PID: \(pid), error: \(result.rawValue)", level: .error)
            return false
        }
        
        // Находим окно с нужным ID
        for window in windows {
            var windowIDValue: CGWindowID = 0
            let idResult = _AXUIElementGetWindow(window, &windowIDValue)
            
            if idResult == .success, windowIDValue == windowID {
                // Выводим окно на передний план
                let raiseResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                
                if raiseResult != .success {
                    Logger.log("Failed to bring window to front: \(raiseResult.rawValue)", level: .error)
                    return false
                }
                
                // Активируем приложение
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.WindowManager")
                if let app = NSRunningApplication(processIdentifier: pid) {
                    if !app.isActive {
                        let activateResult = app.activate(options: .activateIgnoringOtherApps)
                        if !activateResult {
                            Logger.log("Failed to activate application with PID: \(pid)", level: .error)
                            return false
                        }
                    }
                }
                
                return true
            }
        }
        
        Logger.log("Window with ID \(windowID) not found for PID: \(pid)", level: .error)
        return false
    }
} 