import UIKit
import Vision
import ImageIO

enum RecognitionError: Error {
    case invalidImage
}

/// Vision으로 이미지 속 글자를 단어 단위로 읽기
enum TextRecognizer {
    /// 단어와 위치 읽기
    /// - preprocess: 읽기 전에 이미지 정리 (색 배경 → 흰색 등)
    /// - knownNames: 등록된 이름들. Vision의 다른 후보 중 이 이름과 같은 게 있으면 그걸 씀
    static func recognizeWords(
        in image: UIImage,
        preprocess: Bool = false,
        knownNames: [String] = []
    ) async throws -> [OCRWord] {
        guard let cgImage = image.cgImage else { throw RecognitionError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        return try await Task.detached(priority: .userInitiated) {
            let observations = try runVision(cgImage: cgImage, orientation: orientation, preprocess: preprocess)
            return words(from: observations, cgImage: cgImage, orientation: orientation, knownNames: knownNames)
        }.value
    }
    
    /// 테스트용: 줄마다 Vision의 후보 5개
    static func recognizeLineCandidates(in image: UIImage, preprocess: Bool = false) async throws -> [[String]] {
        guard let cgImage = image.cgImage else { throw RecognitionError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        return try await Task.detached(priority: .userInitiated) {
            try runVision(cgImage: cgImage, orientation: orientation, preprocess: preprocess)
                .map { $0.topCandidates(5).map(\.string) }
        }.value
    }
    
    /// Vision 사용 가능 언어 (테스트 화면 표시용)
    static var supportedLanguages: [String] {
        (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? []
    }
    
    // MARK: - Vision 실행
    
    private static func runVision(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        preprocess: Bool
    ) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.minimumTextHeight = 0.01
        
        let (scaled, factor) = upscaledIfSmall(cgImage)
        let source = preprocess ? (ImagePreprocessor.prepare(scaled, scale: factor) ?? scaled) : scaled
        
        let handler = VNImageRequestHandler(cgImage: source, orientation: orientation)
        try handler.perform([request])
        return request.results ?? []
    }
    
    /// Vision 결과 → 단어 목록 (원래 이미지 기준 픽셀 좌표)
    private static func words(
        from observations: [VNRecognizedTextObservation],
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        knownNames: [String]
    ) -> [OCRWord] {
        let isRotated = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
        let width = Double(isRotated ? cgImage.height : cgImage.width)
        let height = Double(isRotated ? cgImage.width : cgImage.height)
        let known = Set(knownNames.map(NameMatching.letters).filter { $0.count >= 3 })
        
        var result: [OCRWord] = []
        for observation in observations {
            guard let candidate = bestCandidate(observation, known: known) else { continue }
            let line = candidate.string
            
            for piece in line.split(whereSeparator: \.isWhitespace) {
                let range = piece.startIndex..<piece.endIndex
                guard let box = try? candidate.boundingBox(for: range)?.boundingBox else { continue }
                
                result.append(OCRWord(
                    text: normalizeLookalikes(String(piece)),
                    confidence: rounded(Double(candidate.confidence) * 100),
                    x0: rounded(Double(box.minX) * width),
                    y0: rounded((1 - Double(box.maxY)) * height),
                    x1: rounded(Double(box.maxX) * width),
                    y1: rounded((1 - Double(box.minY)) * height)
                ))
            }
        }
        return result
    }
    
    /// 1순위 후보. 단, 1순위가 등록된 이름이 아니고 2~5순위 중에 등록된 이름이 있으면 그 후보
    private static func bestCandidate(_ observation: VNRecognizedTextObservation, known: Set<String>) -> VNRecognizedText? {
        let candidates = observation.topCandidates(5)
        guard let first = candidates.first else { return nil }
        guard !known.isEmpty, !known.contains(NameMatching.letters(first.string)) else { return first }
        return candidates.dropFirst().first { known.contains(NameMatching.letters($0.string)) } ?? first
    }
    
    // MARK: - 이미지 키우기
    
    /// 작은 스크린샷은 크게 키워서 읽기 (긴 변 4200px 목표, 최대 3배). 키운 배율도 함께 돌려줌
    private static func upscaledIfSmall(_ image: CGImage) -> (image: CGImage, factor: Double) {
        let longest = Double(max(image.width, image.height))
        let factor = min(3, 4200 / longest)
        guard factor > 1.2 else { return (image, 1) }
        
        let size = CGSize(width: Double(image.width) * factor, height: Double(image.height) * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        guard let output = rendered.cgImage else { return (image, 1) }
        return (output, factor)
    }
    
    // MARK: - 정리
    
    private static let lookalikes: [Character: Character] = [
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", "у": "y", "к": "k", "м": "m", "т": "t",
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X",
        "Α": "A", "Β": "B", "Ε": "E", "Ν": "N", "Ο": "O", "Ρ": "P", "Τ": "T", "Χ": "X", "ο": "o",
    ]
    
    private static func normalizeLookalikes(_ text: String) -> String {
        guard text.contains(where: { $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return text }
        return String(text.map { lookalikes[$0] ?? $0 })
    }
    
    private static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        case .downMirrored:  self = .downMirrored
        case .leftMirrored:  self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
