import UserNotifications

/// 앱을 보고 있을 때도 알림 배너를 띄워요.
/// (기본적으로 iPhone은 앱이 열려 있으면 배너를 숨겨요)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()
    
    /// 앱 시작 시 한 번 불러주세요
    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
