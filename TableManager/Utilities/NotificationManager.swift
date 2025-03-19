//
//  NotificationManager.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import SwiftUI
import Combine

/// Типы уведомлений для пользовательского интерфейса
enum NotificationType {
    case success, warning, error, info
    
    /// Цвет уведомления
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }
    
    /// Иконка уведомления
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// Данные для уведомления
struct NotificationData: Equatable {
    let id: UUID = UUID()
    let message: String
    let type: NotificationType
    let timestamp: Date = Date()
    let duration: TimeInterval
    
    static func == (lhs: NotificationData, rhs: NotificationData) -> Bool {
        lhs.id == rhs.id
    }
}

/// Менеджер для отображения уведомлений в пользовательском интерфейсе
class NotificationManager: ObservableObject {
    /// Текущее активное уведомление
    @Published var currentNotification: NotificationData?
    
    /// История уведомлений
    @Published var notificationHistory: [NotificationData] = []
    
    /// Таймер для автоматического скрытия уведомления
    private var hideTimer: Timer?
    
    /// Максимальное количество хранимых уведомлений
    private let maxHistorySize = 50
    
    /// Синглтон для доступа из разных частей приложения
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Показывает уведомление
    /// - Parameters:
    ///   - message: Текст уведомления
    ///   - type: Тип уведомления
    ///   - duration: Длительность отображения (0 для постоянного)
    func show(_ message: String, type: NotificationType = .info, duration: TimeInterval = 2.0) {
        let notification = NotificationData(message: message, type: type, duration: duration)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Добавляем в историю
            self.notificationHistory.insert(notification, at: 0)
            if self.notificationHistory.count > self.maxHistorySize {
                self.notificationHistory.removeLast()
            }
            
            // Отображаем уведомление с анимацией
            withAnimation(.spring()) {
                self.currentNotification = notification
            }
            
            // Логируем в зависимости от типа
            switch type {
            case .error:
                Logger.log(message, level: .error)
            case .warning:
                Logger.log(message, level: .warning)
            case .success, .info:
                Logger.log(message, level: .info)
            }
            
            // Запускаем таймер для скрытия уведомления
            self.hideTimer?.invalidate()
            if duration > 0 {
                self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    withAnimation(.easeOut) {
                        self?.currentNotification = nil
                    }
                }
            }
        }
    }
    
    /// Скрывает текущее уведомление
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.invalidate()
            withAnimation(.easeOut) {
                self?.currentNotification = nil
            }
        }
    }
}
