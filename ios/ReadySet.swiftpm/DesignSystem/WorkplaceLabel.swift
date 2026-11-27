import SwiftUI

struct WorkplaceLabel: View {
    let workplace: Workplace
    let font: Font
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(workplace.color.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)   // 장식용이므로 VoiceOver에서 제외
            Text(workplace.name)
                .font(font)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        WorkplaceLabel(workplace: SampleData.cafe, font: .body)
        WorkplaceLabel(workplace: SampleData.restaurant, font: .body)
    }
}
