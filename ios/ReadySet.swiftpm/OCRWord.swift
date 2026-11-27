import Foundation

/// OCR이 읽은 단어 하나 (friend's parser.js 입력 형식과 같음)
/// 좌표는 픽셀 단위, 이미지 왼쪽 위가 (0, 0)
struct OCRWord: Hashable, Codable {
    var text: String
    var confidence: Double   // 0~100
    var x0: Double           // 왼쪽
    var y0: Double           // 위
    var x1: Double           // 오른쪽
    var y1: Double           // 아래
    
    // JSON으로 바꿀 때 confidence는 "conf"라는 이름으로 (친구 parser와 맞춤)
    enum CodingKeys: String, CodingKey {
        case text, confidence = "conf", x0, y0, x1, y1
    }
}
