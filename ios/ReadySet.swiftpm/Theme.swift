import SwiftUI
import UIKit

// 앱 전체에서 사용하는 색상
enum AppColor {
    static let primary = Color(red: 51.0 / 255, green: 51.0 / 255, blue: 51.0 / 255)      // #333333
    static let background = Color.white                                                    // #FFFFFF
    static let muted = Color(red: 221.0 / 255, green: 221.0 / 255, blue: 221.0 / 255)      // #DDDDDD
}

// 앱 전체에서 사용하는 폰트
enum AppFont {
    /// Montserrat 폰트를 반환합니다.
    /// 폰트 파일이 아직 앱에 없으면 시스템 폰트를 대신 사용합니다.
    static func montserrat(
        _ size: CGFloat,
        _ weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        let name = fontName(for: weight)
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: style)
        } else {
            return .system(size: size, weight: weight)
        }
    }
    
    private static func fontName(for weight: Font.Weight) -> String {
        if weight == .bold { return "Montserrat-Bold" }
        if weight == .semibold { return "Montserrat-SemiBold" }
        if weight == .medium { return "Montserrat-Medium" }
        return "Montserrat-Regular"
    }
}

extension View {
    /// 흰 배경 + #DDDDDD 테두리 + 둥글기 10 카드
    func cardStyle() -> some View {
        self
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.muted, lineWidth: 1)
            )
    }
}

extension Color {
    /// HEX 값으로 색 만들기: Color(hex: 0x3B7DD8)
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension WorkplaceColor {
    /// 화면에 표시할 실제 색
    var color: Color {
        switch self {
        case .blue:   Color(hex: 0x3B7DD8)
        case .green:  Color(hex: 0x2E9E6A)
        case .orange: Color(hex: 0xE8873A)
        case .purple: Color(hex: 0x8A5CD1)
        case .pink:   Color(hex: 0xD9548F)
        case .teal:   Color(hex: 0x2A9DA8)
        }
    }
}
