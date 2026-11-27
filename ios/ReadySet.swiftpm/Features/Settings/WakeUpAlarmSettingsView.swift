import SwiftUI

/// 미리 정해진 기상 알람 선택지
struct WakeUpPreset: Identifiable {
    let minutes: Int
    let label: String
    var id: Int { minutes }
    
    static let all = [
        WakeUpPreset(minutes: 60,  label: "1 hour before my shift"),
        WakeUpPreset(minutes: 90,  label: "1 hour 30 minutes before"),
        WakeUpPreset(minutes: 120, label: "2 hours before my shift"),
        WakeUpPreset(minutes: 180, label: "3 hours before my shift"),
    ]
}

struct WakeUpAlarmSettingsView: View {
    let initialMinutes: Int
    
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var minutes: Int              // 화면에서 고른 값 (저장 전)
    @State private var isShowingCustom = false
    @State private var isConfirmingSave = false
    
    init(initialMinutes: Int) {
        self.initialMinutes = initialMinutes
        _minutes = State(initialValue: initialMinutes)
    }
    
    /// 미리 정해진 선택지에 없는 값이면 Custom
    private var isCustom: Bool {
        !WakeUpPreset.all.contains { $0.minutes == minutes }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Default Wake-Up Alarm")
                    .font(AppFont.montserrat(26, .bold, relativeTo: .largeTitle))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                Image(systemName: "alarm")
                    .font(.system(size: 28))
                    .padding(.top, 28)
                    .accessibilityHidden(true)
                Text("Wake-up rule")
                    .font(AppFont.montserrat(20, .bold, relativeTo: .title3))
                    .padding(.top, 8)
                Text("Choose when your wake-up alarms should ring.")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                    .padding(.top, 4)
                
                Text("How early do you want to wake up?")
                    .font(AppFont.montserrat(15, .semibold, relativeTo: .headline))
                    .padding(.top, 24)
                
                VStack(spacing: 8) {
                    ForEach(WakeUpPreset.all) { preset in
                        RadioRow(title: preset.label, isSelected: minutes == preset.minutes) {
                            minutes = preset.minutes
                        }
                    }
                    RadioRow(
                        title: isCustom ? "Custom: \(TextFormat.longDuration(minutes: minutes))" : "Custom time",
                        isSelected: isCustom,
                        showsChevron: true
                    ) {
                        withAnimation { isShowingCustom = true }
                    }
                }
                .padding(.top, 14)
                
                AlarmExampleCard(minutesBefore: minutes)
                    .padding(.top, 20)
                
                SettingsNote(text: "Changes here will update all scheduled wake-up alarms.")
                    .padding(.top, 12)
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save Changes", minHeight: 52) {
                isConfirmingSave = true
            }
            .disabled(minutes == initialMinutes)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(AppColor.background)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isShowingCustom)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if isShowingCustom {
                CustomWakeUpDialog(
                    initialMinutes: minutes,
                    onApply: { newMinutes in
                        minutes = newMinutes
                        withAnimation { isShowingCustom = false }
                    },
                    onClose: {
                        withAnimation { isShowingCustom = false }
                    }
                )
                .transition(.opacity)
            }
        }
        // 저장 전 경고
        .alert("Update all wake-up alarms?", isPresented: $isConfirmingSave) {
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                store.alarmSettings.wakeUpMinutesBefore = minutes
                // TODO (Phase 4): 예약된 기상 알람 모두 다시 예약
                dismiss()
            }
        } message: {
            Text("Every wake-up alarm will ring \(TextFormat.longDuration(minutes: minutes)) before its shift, including shifts you've already added.")
        }
    }
}

// MARK: - 알람 예시 (6:00 AM 근무 기준)
struct AlarmExampleCard: View {
    let minutesBefore: Int
    
    var body: some View {
        let calendar = Calendar.current
        let shiftStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: .now) ?? .now
        let wakeUp = shiftStart.addingTimeInterval(-Double(minutesBefore) * 60)
        let isDayBefore = !calendar.isDate(wakeUp, inSameDayAs: shiftStart)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Alarm example")
                .font(AppFont.montserrat(15, .semibold, relativeTo: .headline))
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shift starts")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                    Text(shiftStart.shortTimeText)
                        .font(AppFont.montserrat(17, .bold, relativeTo: .headline))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isDayBefore ? "Wake-up alarm (day before)" : "Wake-up alarm")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                    Text(wakeUp.shortTimeText)
                        .font(AppFont.montserrat(17, .bold, relativeTo: .headline))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Custom Wake-Up Time 창 (휠 선택기)
struct CustomWakeUpDialog: View {
    let onApply: (Int) -> Void
    let onClose: () -> Void
    
    @State private var hours: Int
    @State private var minutes: Int
    
    init(initialMinutes: Int, onApply: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.onApply = onApply
        self.onClose = onClose
        _hours = State(initialValue: min(initialMinutes / 60, 12))
        _minutes = State(initialValue: initialMinutes % 60)
    }
    
    private var total: Int { hours * 60 + minutes }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Wake-Up Time")
                            .font(AppFont.montserrat(18, .bold, relativeTo: .title3))
                        Text("How long before your shift should your alarm ring?")
                            .font(AppFont.montserrat(12, relativeTo: .footnote))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                
                HStack(spacing: 12) {
                    wheel(title: "Hours", selection: $hours, range: 0...12, unit: "hr")
                    wheel(title: "Minutes", selection: $minutes, range: 0...59, unit: "min")
                }
                .padding(.top, 20)
                
                VStack(spacing: 4) {
                    Label("Alarm preview", systemImage: "alarm")
                        .font(AppFont.montserrat(13, .semibold, relativeTo: .subheadline))
                    Text(total > 0
                         ? "\(TextFormat.longDuration(minutes: total)) before each shift"
                         : "Choose at least 1 minute.")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                
                PrimaryButton(title: "Apply Custom Time", minHeight: 48) {
                    onApply(total)
                }
                .disabled(total == 0)
                .padding(.top, 16)
            }
            .foregroundStyle(AppColor.primary)
            .padding(24)
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }
    
    private func wheel(title: String, selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(unit)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()
            .cardStyle()
        }
    }
}

#Preview {
    NavigationStack {
        WakeUpAlarmSettingsView(initialMinutes: 120)
    }
    .environmentObject(ShiftStore.sample)
}
