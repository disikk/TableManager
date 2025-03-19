//
//  WindowType.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation

/// Defines a type of window to detect and manage
struct WindowType: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier
    var id: String
    
    /// Display name for this window type
    var name: String
    
    /// Pattern to match window titles (* for wildcard)
    var titlePattern: String
    
    /// Pattern to match window class (* for wildcard)
    var classPattern: String
    
    /// Whether this window type is enabled
    var enabled: Bool
    
    // Кэш регулярных выражений с ограничением размера
    private static var regexCache: [String: NSRegularExpression] = [:]
    private static let maxRegexCacheSize = 50
    
    /// Добавьте этот метод в класс WindowType
    private static func addToRegexCache(pattern: String, regex: NSRegularExpression) {
        // Если кэш достиг максимального размера, удаляем первый элемент
        if regexCache.count >= maxRegexCacheSize {
            if let firstKey = regexCache.keys.first {
                regexCache.removeValue(forKey: firstKey)
            }
        }
        regexCache[pattern] = regex
    }
    
    /// Check if a window matches this type
    /// - Parameters:
    ///   - title: Window title to check
    ///   - windowClass: Window class to check
    /// - Returns: True if window matches this type
    func matches(title: String, windowClass: String) -> Bool {
        guard enabled else { return false }
        
        return matchesPattern(title, pattern: titlePattern) &&
               matchesPattern(windowClass, pattern: classPattern)
    }
    
    /// Checks if a string matches a pattern with wildcards
    /// - Parameters:
    ///   - string: String to check
    ///   - pattern: Pattern with * wildcards
    /// - Returns: True if string matches pattern
    private func matchesPattern(_ string: String, pattern: String) -> Bool {
        // If pattern is empty or *, it matches anything
        if pattern.isEmpty || pattern == "*" {
            return true
        }
        
        // Создаем ключ для кэша
        let escapedPattern = NSRegularExpression.escapedPattern(for: pattern)
        let regexPattern = "^\(escapedPattern.replacingOccurrences(of: "\\*", with: ".*"))$"
        
        let regex: NSRegularExpression
        if let cachedRegex = Self.regexCache[regexPattern] {
            // Используем кэшированное выражение
            regex = cachedRegex
        } else {
            do {
                // Создаем новое регулярное выражение
                regex = try NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive])
                // Добавляем в кэш с ограничением размера
                Self.addToRegexCache(pattern: regexPattern, regex: regex)
            } catch {
                Logger.log("Invalid regex pattern: \(error)", level: .error)
                return false
            }
        }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
    
    /// Create a copy of this window type with a new ID
    func copy() -> WindowType {
        return WindowType(
            id: UUID().uuidString,
            name: "\(name) (Copy)",
            titlePattern: titlePattern,
            classPattern: classPattern,
            enabled: enabled
        )
    }
    
    // Equatable implementation
    static func == (lhs: WindowType, rhs: WindowType) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
