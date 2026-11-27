import SwiftUI

/// 근무표를 읽는 동안 화면 가운데에 보여주는 로딩 카드
struct FindingShiftsOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageIndex = 0
    
    private let messages = [
        "Reading your schedule…",
        "Looking for names…",
        "Finding your shifts…",
        "Almost done…"
    ]
    
    var body: some View {
        ZStack {
            // 뒤 화면을 살짝 어둡게 + 터치 막기
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ScanningDocument(isAnimated: !reduceMotion)
                
                VStack(spacing: 6) {
                    ZStack {
                        Text(messages[messageIndex])
                            .font(.custom("Montserrat", size: 17, relativeTo: .headline).weight(.semibold))
                            .foregroundStyle(AppColor.primary)
                            .id(messageIndex)
                            .transition(.opacity)
                    }
                    
                    Text("This can take a few seconds.")
                        .font(.custom("Montserrat", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                }
                .multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .frame(maxWidth: 300)
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.muted, lineWidth: 1)
            )
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .task {
            // 문구를 차례로 바꾸고 마지막 문구에서 멈춰요
            for index in 1..<messages.count {
                try? await Task.sleep(for: .seconds(1.6))
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageIndex = index
                }
            }
        }
    }
}

/// 스캔 선이 위아래로 움직이는 문서 아이콘
private struct ScanningDocument: View {
    let isAnimated: Bool
    @State private var isAtBottom = false
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.background)
            
            // 문서 안의 표 줄 모양
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 6) {
                        Capsule().frame(width: 14, height: 5)
                        Capsule().frame(width: row.isMultiple(of: 2) ? 26 : 18, height: 5)
                    }
                }
            }
            .foregroundStyle(AppColor.muted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColor.primary, lineWidth: 2)
            
            if isAnimated {
                Capsule()
                    .fill(AppColor.primary)
                    .frame(height: 3)
                    .padding(.horizontal, 5)
                    .offset(y: isAtBottom ? 80 : 5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                            isAtBottom = true
                        }
                    }
            }
        }
        .frame(width: 64, height: 88)
        .accessibilityHidden(true)
    }
}

#Preview {
    FindingShiftsOverlay()
}
