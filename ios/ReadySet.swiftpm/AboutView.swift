import SwiftUI

struct AboutView: View {
    /// 앱 설정의 버전 번호 (예: "1.0.0")
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("About")
                    .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                // TODO: 앱 아이콘 이미지가 생기면 교체
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColor.muted)
                    .frame(width: 64, height: 64)
                    .padding(.top, 32)
                    .accessibilityHidden(true)
                
                Text("ReadySet")
                    .font(AppFont.montserrat(24, .bold, relativeTo: .title))
                    .padding(.top, 16)
                Text("Version \(version)")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.6))
                    .padding(.top, 4)
                
                VStack(spacing: 10) {
                    SettingsRow(title: "Privacy Policy", route: .privacyPolicy)
                        .cardStyle()
                    SettingsRow(title: "Terms of Service", route: .termsOfService)
                        .cardStyle()
                    SettingsRow(title: "Contact Support", route: .contactSupport)
                        .cardStyle()
                }
                .padding(.top, 28)
                
                Text("© 2026 ReadySet")
                    .font(AppFont.montserrat(11, relativeTo: .caption))
                    .foregroundStyle(AppColor.primary.opacity(0.6))
                    .padding(.top, 80)
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
