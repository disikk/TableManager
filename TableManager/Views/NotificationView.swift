import SwiftUI

struct NotificationView: View {
    let notification: NotificationData
    var onDismiss: () -> Void
    
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка
            Image(systemName: notification.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(notification.type.color)
                .clipShape(Circle())
            
            // Сообщение
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(timeAgo(from: notification.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Кнопка закрытия
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .opacity($opacity.wrappedValue)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.2)) {
                opacity = 1.0
            }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.2)) {
                opacity = 0.0
            }
        }
    }
} 