import UserNotifications

/// 알림 권한 확인·요청
enum NotificationPermission {
    /// 현재 권한 상태
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    
    /// 권한 요청 (처음 한 번만 시스템 창이 뜸). 허용하면 true
    @discardableResult
    static func request() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }
}
