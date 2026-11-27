import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var minHeight: CGFloat = 80
    let action: () -> Void
    
    // .disabled(true)가 붙으면 SwiftUI가 자동으로 false를 넣어줌
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.montserrat(16, .semibold, relativeTo: .headline))
            }
            .foregroundStyle(isEnabled ? AppColor.background : AppColor.primary.opacity(0.4))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                isEnabled ? AppColor.primary : AppColor.muted,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Add your first schedule", systemImage: "plus") { }
        PrimaryButton(title: "Add my shifts", minHeight: 52) { }
        PrimaryButton(title: "Add my shifts", minHeight: 52) { }
            .disabled(true)
    }
    .padding()
}
