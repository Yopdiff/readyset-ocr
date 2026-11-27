import SwiftUI

// MARK: - 라디오 버튼 아이콘 (● / ○)
struct RadioIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 18))
            .accessibilityHidden(true)
    }
}

// MARK: - 하나만 고르는 줄
struct RadioRow: View {
    let title: String
    let isSelected: Bool
    var showsChevron = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RadioIcon(isSelected: isSelected)
                Text(title)
                    .font(AppFont.montserrat(14, relativeTo: .body))
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 화면 아래 안내 문구
struct SettingsNote: View {
    let text: String
    
    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(AppFont.montserrat(11, relativeTo: .caption))
            .foregroundStyle(AppColor.primary.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 여러 개 고르는 줄 (체크박스)
struct CheckboxRow: View {
    let title: String
    let isChecked: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFont.montserrat(14, relativeTo: .body))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
