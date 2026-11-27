import Foundation

/// 이미 읽어 둔 근무표 한 장: 이름 목록을 주면 그 사람의 근무를 찾아줌
/// TODO (Phase 3): Vision이 읽은 글자 목록 + ShiftParser로 만들기
struct RecognizedSchedule {
    let extract: (_ names: [String]) -> ExtractionResult
    
    /// 이름과 상관없이 항상 같은 결과 (테스트용)
    static func fixed(_ result: ExtractionResult) -> RecognizedSchedule {
        RecognizedSchedule { _ in result }
    }
}
