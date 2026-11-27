import Foundation
import UserNotifications

/// 근무 목록과 설정을 보고 Shift reminder 알림을 다시 예약해요.
enum ReminderScheduler {
    
    /// 우리 앱 리마인더 알림만 구분하기 위한 이름 앞부분
    private static let prefix = "shift-reminder-"
    
    /// iPhone 한도(64개)보다 조금 적게
    private static let maxPending = 60
    
    static func sync(shifts: [Shift], settings: AlarmSettings, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        
        // 1. 예전에 예약한 리마인더 전부 지우기
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)
        
        // 2. 리마인더가 꺼져 있거나 알림 권한이 없으면 여기서 끝
        guard settings.remindersEnabled else { return }
        let permission = await center.notificationSettings()
        guard permission.authorizationStatus == .authorized
                || permission.authorizationStatus == .provisional else { return }
        
        // 3. 앞으로 울릴 알림 목록 만들기 (가까운 순서)
        var plans: [(shift: Shift, minutes: Int, fireDate: Date)] = []
        for shift in shifts {
            for minutes in settings.reminderMinutesBefore {
                let fireDate = shift.start.addingTimeInterval(-Double(minutes) * 60)
                if fireDate > now {
                    plans.append((shift, minutes, fireDate))
                }
            }
        }
        plans.sort { $0.fireDate < $1.fireDate }
        
        // 4. 60개까지만 예약
        for plan in plans.prefix(maxPending) {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming shift"
            content.body = message(for: plan.shift, minutes: plan.minutes)
            content.sound = .default
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "\(prefix)\(plan.shift.id)-\(plan.minutes)",
                content: content,
                trigger: trigger)
            try? await center.add(request)
        }
    }
    
    /// 예: "Café A · Thu, Nov 26 at 6:00 PM (in 12 hours)"
    private static func message(for shift: Shift, minutes: Int) -> String {
        let day = shift.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let time = shift.start.formatted(date: .omitted, time: .shortened)
        return "\(shift.workplace.name) · \(day) at \(time) (in \(leadText(minutes)))"
    }
    
    /// 30 → "30 minutes", 60 → "1 hour", 720 → "12 hours"
    private static func leadText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }
}
