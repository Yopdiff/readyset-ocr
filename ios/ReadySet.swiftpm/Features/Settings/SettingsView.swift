import SwiftUI

/// Settings 탭에서 이동할 수 있는 화면들
enum SettingsRoute: Hashable {
    case wakeUpAlarm, alarmSound, shiftReminders, workplaces, about
    case privacyPolicy, termsOfService, contactSupport
}

struct SettingsView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var isConfirmingErase = false
    
    var body: some View {
        let settings = store.alarmSettings
        
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                        .padding(.top, 24)
                    Text("Manage your alarms and workplaces.")
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                        .padding(.top, 4)
                    
                    SettingsSection(title: "Alarm Settings") {
                        SettingsRow(
                            title: "Default wake-up alarm",
                            subtitle: "\(TextFormat.longDuration(minutes: settings.wakeUpMinutesBefore)) before each shift",
                            route: .wakeUpAlarm
                        )
                        Divider().padding(.horizontal, 16)
                        SettingsRow(
                            title: "Alarm sound",
                            subtitle: settings.sound.displayName,
                            route: .alarmSound
                        )
                    }
                    
                    SettingsSection(title: "Notifications") {
                        SettingsRow(
                            title: "Shift reminders",
                            subtitle: "Reminder times and notification permissions",
                            route: .shiftReminders
                        )
                    }
                    
                    SettingsSection(title: "Workplaces") {
                        SettingsRow(
                            title: "Manage workplaces",
                            subtitle: "Add, edit or remove workplaces",
                            route: .workplaces
                        )
                    }
                    
                    SettingsSection(title: "About") {
                        SettingsRow(
                            title: "App information",
                            subtitle: "Version, privacy & support",
                            route: .about
                        )
                    }
                    
                    // TODO: 출시 전 삭제 (개발·테스트용)
                    SettingsSection(title: "Developer") {
                        DeveloperRow(
                            title: "Load sample data",
                            subtitle: "Adds Café A, Restaurant B and a few shifts. Only works when the app is empty.",
                            isEnabled: store.workplaces.isEmpty && store.shifts.isEmpty
                        ) {
                            store.loadSampleData()
                        }
                        Divider().padding(.horizontal, 16)
                        DeveloperRow(
                            title: "Erase all data",
                            subtitle: "Deletes every workplace, shift and setting on this device.",
                            isDestructive: true
                        ) {
                            isConfirmingErase = true
                        }
                        Divider().padding(.horizontal, 16)
                        OCRTestLinkRow()
                        ReminderTestLinkRow()
                    }
                }
                .foregroundStyle(AppColor.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .about:
                    AboutView()
                case .wakeUpAlarm:
                    WakeUpAlarmSettingsView(initialMinutes: store.alarmSettings.wakeUpMinutesBefore)
                case .alarmSound:
                    AlarmSoundSettingsView(initialSound: store.alarmSettings.sound)
                case .shiftReminders:
                    ShiftRemindersSettingsView(initialSettings: store.alarmSettings)
                case .workplaces:
                    ManageWorkplacesView()
                case .privacyPolicy:
                    SettingsDetailPlaceholder(title: "Privacy Policy")          // TODO: 출시 준비
                case .termsOfService:
                    SettingsDetailPlaceholder(title: "Terms of Service")        // TODO: 출시 준비
                case .contactSupport:
                    SettingsDetailPlaceholder(title: "Contact Support")         // TODO: 출시 준비
                }
            }
            .alert("Erase all data?", isPresented: $isConfirmingErase) {
                Button("Cancel", role: .cancel) { }
                Button("Erase", role: .destructive) { store.eraseAllData() }
            } message: {
                Text("This deletes every workplace, shift and setting on this device. This can't be undone.")
            }
        }
    }
}

// MARK: - 제목 + 카드로 묶인 구역
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.montserrat(17, .semibold, relativeTo: .headline))
            VStack(spacing: 0) {
                content
            }
            .cardStyle()
        }
        .padding(.top, 28)
    }
}

// MARK: - 누르면 다음 화면으로 가는 한 줄
struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    let route: SettingsRoute
    
    var body: some View {
        NavigationLink(value: route) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.montserrat(14, .semibold, relativeTo: .subheadline))
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.montserrat(11, relativeTo: .caption))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 개발용 버튼 줄 (TODO: 출시 전 삭제)
struct DeveloperRow: View {
    let title: String
    let subtitle: String
    var isEnabled = true
    var isDestructive = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.montserrat(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(isDestructive ? Color.red : AppColor.primary)
                Text(subtitle)
                    .font(AppFont.montserrat(11, relativeTo: .caption))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ShiftStore.sample)
}
