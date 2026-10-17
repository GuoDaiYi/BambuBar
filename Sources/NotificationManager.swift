import Foundation
import AppKit
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private var requested = false

    func request() {
        guard !requested else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.write("Notification permission error: \(error.localizedDescription)")
            } else {
                Log.write("Notification permission granted: \(granted)")
            }
        }
    }

    func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.write("Notification failed: \(error.localizedDescription)")
            }
        }
    }
}
