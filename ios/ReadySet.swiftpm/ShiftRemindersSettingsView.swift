import SwiftUI
import UserNotifications

struct ShiftRemindersSettingsView: View {
    let initialSettings: AlarmSettings
    
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isEnabled: Bool
    @State private var selected: Set<Int>                 // 고른 리마인더 (근무 몇 분 전)
    @State private var permission: UNAuthorizationStatus?
    @State private var isConfirmingSave = false
    
    /// 선택지: 30분, 1시간, 3시간, 6시간, 12시간, 24시간 전
    private static let options = [30, 60, 180, 360, 720, 1440]
    private let maxSelection = 3
    
    init(initialSettings: AlarmSettings) {
        self.initialSettings = initialSettings
        _isEnabled = State(initialValue: initialSettings.remindersEnabled)
        _selected = State(initialValue: Set(initialSettings.reminderMinutesBefore))
    }
    
    // MARK: 계산 값
    
    private var hasChanges: Bool {
        isEnabled != initialSettings.remindersEnabled
        || selected != Set(initialSettings.reminderMinutesBefore)
    }
    
    /// 저장할 수 없는 이유 (저장 가능하면 nil)
    private var saveBlocker: String? {
        if isEnabled && selected.isEmpty {
            return "Choose at least one reminder time, or turn reminders off."
        }
        return nil
    }
    
    /// "12 hours and 1 hour"
    private var selectedSummary: String {
        selected.sorted(by: >)
            .map { TextFormat.longDuration(minutes: $0) }
            .formatted(.list(type: .and))
    }
    
    private var permissionText: String {
        switch permission {
        case .authorized, .provisional, .ephemeral:
            return "Allowed · Manage in iPhone Settings"
        case .denied:
            return "Off · Turn on in iPhone Settings"
        case .notDetermined:
            return "Tap to allow notifications"
        default:
            return "Manage in iPhone Settings"
        }
    }
    
    // MARK: 화면
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Shift Reminders")
                    .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    .padding(.top, 8)
                
                // 켜기/끄기
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable reminders")
                            .font(AppFont.montserrat(16, .semibold, relativeTo: .headline))
                        Text("Get reminders before each shift.")
                            .font(AppFont.montserrat(12, relativeTo: .footnote))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                }
                .tint(AppColor.primary)
                .padding(16)
                .background(AppColor.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 24)
                
                // 리마인더 시간
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminder timing")
                            .font(AppFont.montserrat(15, .semibold, relativeTo: .headline))
                        Text("Choose when to get notified")
                            .font(AppFont.montserrat(11, relativeTo: .caption))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    Spacer()
                    Text("Select up to \(maxSelection)")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                }
                .padding(.top, 24)
                
                VStack(spacing: 8) {
                    ForEach(Self.options, id: \.self) { minutes in
                        let isChecked = selected.contains(minutes)
                        CheckboxRow(
                            title: "\(TextFormat.longDuration(minutes: minutes)) before",
                            isChecked: isChecked,
                            isEnabled: isEnabled && (isChecked || selected.count < maxSelection)
                        ) {
                            toggle(minutes)
                        }
                    }
                }
                .padding(.top, 12)
                
                // 알림 권한
                Button {
                    Task { await handlePermissionTap() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notification permissions")
                                .font(AppFont.montserrat(14, .semibold, relativeTo: .subheadline))
                            Text(permissionText)
                                .font(AppFont.montserrat(11, relativeTo: .caption))
                                .foregroundStyle(AppColor.primary.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                    .cardStyle()
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                
                if isEnabled && permission == .denied {
                    ReviewNote(text: "Notifications are turned off for this app, so you won't get reminders. Turn them on in iPhone Settings.")
                        .padding(.top, 10)
                }
                
                SettingsNote(text: "Changes apply to all scheduled shift reminders.")
                    .padding(.top, 12)
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let saveBlocker {
                    Text(saveBlocker)
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "Save Changes", minHeight: 52) {
                    isConfirmingSave = true
                }
                .disabled(!hasChanges || saveBlocker != nil)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(AppColor.background)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        // 화면이 뜰 때, 그리고 설정 앱에서 돌아올 때마다 권한 상태 다시 확인
        .task(id: scenePhase) {
            if scenePhase == .active {
                permission = await NotificationPermission.status()
            }
        }
        .alert("Update all shift reminders?", isPresented: $isConfirmingSave) {
            Button("Cancel", role: .cancel) { }
            Button("Update") { save() }
        } message: {
            Text(isEnabled
                 ? "You'll get reminders \(selectedSummary) before every shift, including shifts you've already added."
                 : "You won't get reminders for any shift.")
        }
    }
    
    // MARK: - 동작
    
    private func toggle(_ minutes: Int) {
        if selected.contains(minutes) {
            selected.remove(minutes)
        } else if selected.count < maxSelection {
            selected.insert(minutes)
        }
    }
    
    private func handlePermissionTap() async {
        if permission == .notDetermined {
            await NotificationPermission.request()
            permission = await NotificationPermission.status()
            store.refreshReminders()          // 허락받은 직후 바로 예약
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }
    
    private func save() {
        // 한 번에 바꾸기 → ShiftStore가 저장하고 리마인더도 다시 예약
        var settings = store.alarmSettings
        settings.remindersEnabled = isEnabled
        settings.reminderMinutesBefore = selected.sorted()
        store.alarmSettings = settings
        
        // 켰는데 아직 권한을 안 물어봤다면: 권한 요청 → 다시 예약
        if isEnabled && permission == .notDetermined {
            let store = store
            Task {
                await NotificationPermission.request()
                store.refreshReminders()
            }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ShiftRemindersSettingsView(initialSettings: AlarmSettings())
    }
    .environmentObject(ShiftStore.sample)
}
