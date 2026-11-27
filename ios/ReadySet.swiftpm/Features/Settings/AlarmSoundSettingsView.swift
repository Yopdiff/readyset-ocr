import SwiftUI

struct AlarmSoundSettingsView: View {
    let initialSound: AlarmSound
    
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State private var sound: AlarmSound
    
    init(initialSound: AlarmSound) {
        self.initialSound = initialSound
        _sound = State(initialValue: initialSound)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Alarm Sound")
                    .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    .padding(.top, 8)
                Text("Choose a sound for your wake-up alarms.")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                    .padding(.top, 4)
                
                VStack(spacing: 8) {
                    ForEach(AlarmSound.allCases, id: \.self) { option in
                        SoundRow(sound: option, isSelected: sound == option) {
                            sound = option
                        }
                    }
                }
                .padding(.top, 24)
                
                SettingsNote(text: "The selected sound will be used for your wake-up alarms.")
                    .padding(.top, 12)
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save Changes", minHeight: 52) {
                store.alarmSettings.sound = sound
                // TODO (Phase 4): 예약된 기상 알람의 소리 변경
                dismiss()
            }
            .disabled(sound == initialSound)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(AppColor.background)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - 소리 한 줄 (선택 + 미리듣기)
struct SoundRow: View {
    let sound: AlarmSound
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    RadioIcon(isSelected: isSelected)
                    Text(sound.displayName)
                        .font(AppFont.montserrat(14, relativeTo: .body))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            
            // TODO: 소리 파일이 준비되면 미리듣기 연결
            Button { } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.3)
            .accessibilityLabel("Preview \(sound.displayName), not available yet")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        AlarmSoundSettingsView(initialSound: .standard)
    }
    .environmentObject(ShiftStore.sample)
}
