import SwiftUI
import PhotosUI

/// 개발용: Vision이 근무표를 어떻게 읽는지 확인 (TODO: 출시 전 삭제)
struct OCRTestView: View {
    @EnvironmentObject private var store: ShiftStore
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var words: [OCRWord] = []
    @State private var nameLineCandidates: [[String]] = []
    @State private var status = "Choose a schedule image to test."
    @State private var didCopy = false
    
    @State private var usePreprocessing = false
    @State private var useKnownNames = false
    
    /// 테스트용 이름 (앱에서 입력할 수 없어서 코드로). 필요하면 바꾸세요
    private let extraTestNames = ["Jiwoo", "Cyrus"]
    
    /// 등록된 직장들의 이름 + 기억한 별칭 + 테스트용 이름
    private var knownNames: [String] {
        (store.workplaces.flatMap { [$0.nameOnSchedule] + $0.aliases } + extraTestNames)
            .filter { !$0.isEmpty }
    }
    
    private var koreanSupported: Bool {
        TextRecognizer.supportedLanguages.contains { $0.hasPrefix("ko") }
    }
    
    /// 이 값이 바뀌면 다시 읽기
    private struct RunKey: Hashable {
        let item: PhotosPickerItem?
        let preprocess: Bool
        let knownNames: Bool
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Choose image", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .cardStyle()
                }
                .buttonStyle(.plain)
                
                Toggle("Preprocess image (beta)", isOn: $usePreprocessing)
                Toggle("Prefer known names", isOn: $useKnownNames)
                Text("Known names: \(knownNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(status)
                    .font(.subheadline.bold())
                
                Text("Korean supported: \(koreanSupported ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Parser ready: \(ScheduleParser.shared.isReady ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let image {
                    OCRBoxesOverlay(image: image, words: words)
                }
                
                // 이름처럼 보이는 줄의 다른 후보들
                if !nameLineCandidates.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Other guesses for name-like lines")
                            .font(.subheadline.bold())
                        ForEach(nameLineCandidates.indices, id: \.self) { index in
                            Text(nameLineCandidates[index].joined(separator: "  |  "))
                                .font(.caption.monospaced())
                        }
                    }
                }
                
                if !words.isEmpty {
                    Button {
                        copyJSON()
                    } label: {
                        Label(didCopy ? "Copied!" : "Copy words as JSON", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .cardStyle()
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(words.indices, id: \.self) { index in
                            HStack {
                                Text(words[index].text)
                                Spacer()
                                Text("\(Int(words[index].confidence))%")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption.monospaced())
                        }
                    }
                }
            }
            .foregroundStyle(AppColor.primary)
            .padding(24)
        }
        .background(AppColor.background)
        .navigationTitle("OCR Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: RunKey(item: selectedItem, preprocess: usePreprocessing, knownNames: useKnownNames)) {
            await runRecognition()
        }
    }
    
    private func runRecognition() async {
        guard let selectedItem else { return }
        words = []
        nameLineCandidates = []
        didCopy = false
        status = "Reading…"
        
        guard let loaded = await ImageLoading.loadImage(from: selectedItem) else {
            status = "Couldn't open this image."
            return
        }
        image = loaded
        
        let start = Date()
        do {
            words = try await TextRecognizer.recognizeWords(
                in: loaded,
                preprocess: usePreprocessing,
                knownNames: useKnownNames ? knownNames : []
            )
            let seconds = Date().timeIntervalSince(start)
            status = "\(words.count) words in \(String(format: "%.1f", seconds)) s"
            + (usePreprocessing ? " · preprocessed" : "")
            + (useKnownNames ? " · known names" : "")
            
            // 글자는 있고 숫자는 없는 줄(이름처럼 보이는 줄) 중 후보가 여러 개인 것만
            nameLineCandidates = try await TextRecognizer
                .recognizeLineCandidates(in: loaded, preprocess: usePreprocessing)
                .filter { candidates in
                    guard let first = candidates.first else { return false }
                    return Set(candidates).count > 1
                    && first.contains(where: \.isLetter)
                    && !first.contains(where: \.isNumber)
                }
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }
    
    private func copyJSON() {
        guard let data = try? JSONEncoder().encode(words),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UIPasteboard.general.string = json
        didCopy = true
    }
}

/// 이미지 위에 단어 위치를 빨간 상자로 표시
struct OCRBoxesOverlay: View {
    let image: UIImage
    let words: [OCRWord]
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    let scaleX = geometry.size.width / (image.size.width * image.scale)
                    let scaleY = geometry.size.height / (image.size.height * image.scale)
                    
                    ForEach(words.indices, id: \.self) { index in
                        let word = words[index]
                        Rectangle()
                            .stroke(Color.red, lineWidth: 1)
                            .frame(
                                width: CGFloat(word.x1 - word.x0) * scaleX,
                                height: CGFloat(word.y1 - word.y0) * scaleY
                            )
                            .position(
                                x: CGFloat(word.x0 + word.x1) / 2 * scaleX,
                                y: CGFloat(word.y0 + word.y1) / 2 * scaleY
                            )
                    }
                }
            }
            .cardStyle()
    }
}

/// Settings의 Developer 구역에 넣는 줄
struct OCRTestLinkRow: View {
    var body: some View {
        NavigationLink {
            OCRTestView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OCR test")
                        .font(AppFont.montserrat(14, .semibold, relativeTo: .subheadline))
                    Text("See what Vision reads from a schedule image.")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
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
