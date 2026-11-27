import SwiftUI
import UserNotifications

/// 개발용: 리마인더 알림 상태 확인 (TODO: 출시 전 삭제)
struct ReminderTestView: View {
    @EnvironmentObject private var store: ShiftStore
    
    @State private var permissionText = "Checking…"
    @State private var pending: [PendingItem] = []
    @State private var message = ""
    
    struct PendingItem: Identifiable {
        let id: String
        let body: String
        let fireDate: Date?
    }
    
    var body: some View {
        Form {
            Section("Permission") {
                LabeledContent("Notifications", value: permissionText)
                Button("Ask for permission") {
                    Task { await askPermission() }
                }
            }
            
            Section("Settings") {
                LabeledContent("Reminders", value: store.alarmSettings.remindersEnabled ? "On" : "Off")
                LabeledContent("Before shift",
                               value: store.alarmSettings.reminderMinutesBefore.map { "\($0)m" }.joined(separator: ", "))
                LabeledContent("Future shifts", value: "\(store.shifts.filter { $0.start > .now }.count)")
                LabeledContent("AlarmKit", value: AlarmKitCheck.canImport ? "Available" : "Not available")
                LabeledContent("Alarm usage text", value: AlarmKitCheck.hasUsageDescription ? "Found" : "Missing")
            }
            
            Section {
                Button("Send test notification in 10 seconds") {
                    Task { await sendTest() }
                }
                Button("Refresh reminders") {
                    store.refreshReminders()
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await reload()
                    }
                }
                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("After tapping the test button, go to the Home Screen right away. Banners don't show while the app is open yet.")
            }
            
            Section("Scheduled reminders (\(pending.count))") {
                if pending.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                }
                WakeAlarmPlanSection()
                ForEach(pending) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.fireDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown time")
                            .font(.subheadline.weight(.semibold))
                        Text(item.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Reminder test")
        .task { await reload() }
        .refreshable { await reload() }
    }
    
    // MARK: - 동작
    
    private func reload() async {
        let center = UNUserNotificationCenter.current()
        
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: permissionText = "Allowed"
        case .provisional: permissionText = "Provisional"
        case .denied: permissionText = "Denied"
        case .notDetermined: permissionText = "Not asked yet"
        case .ephemeral: permissionText = "Ephemeral"
        @unknown default: permissionText = "Unknown"
        }
        
        let requests = await center.pendingNotificationRequests()
        pending = requests
            .filter { $0.identifier.hasPrefix("shift-reminder-") }
            .map { request in
                let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                return PendingItem(id: request.identifier, body: request.content.body, fireDate: date)
            }
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }
    
    private func askPermission() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        message = granted ? "Permission granted." : "Permission not granted."
        store.refreshReminders()
        try? await Task.sleep(for: .seconds(1))
        await reload()
    }
    
    private func sendTest() async {
        let content = UNMutableNotificationContent()
        content.title = "Test notification"
        content.body = "If you see this, notifications work."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID())", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            message = "Test scheduled. Go to the Home Screen now."
        } catch {
            message = "Couldn't schedule: \(error.localizedDescription)"
        }
    }
}

/// Settings의 Developer 구역에 넣을 줄
struct ReminderTestLinkRow: View {
    var body: some View {
        NavigationLink {
            ReminderTestView()
        } label: {
            Text("Reminder test")
        }
    }
}
