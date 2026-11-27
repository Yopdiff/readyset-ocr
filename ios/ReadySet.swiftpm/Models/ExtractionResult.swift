import Foundation

/// 근무표에서 찾아낸 근무 1건 (아직 저장 전)
struct ExtractedShift: Identifiable, Hashable {
    let id: UUID
    var start: Date
    var end: Date?             // nil = 근무표에 "마감(CL)"으로만 적힘   ← parser: toClose
    var isTimeAssumed: Bool    // AM/PM이 없어서 추정함                ← parser: assumed
    var rawText: String        // 근무표 원문 (예: "6-1:30")            ← parser: raw
    
    init(id: UUID = UUID(), start: Date, end: Date?, isTimeAssumed: Bool = false, rawText: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.isTimeAssumed = isTimeAssumed
        self.rawText = rawText
    }
    
    /// 다음 날 끝나는 근무인지
    var isOvernight: Bool {
        guard let end else { return false }
        return !Calendar.current.isDate(end, inSameDayAs: start)
    }
    
    /// 사용자가 확인해야 하는 근무인지
    var needsReview: Bool {
        isTimeAssumed || end == nil
    }
}

/// 근무표에서 찾은 이름 후보
struct NameCandidate: Hashable {
    var label: String          // 근무표에 적힌 이름 (예: "Park, J.")
    var score: Double          // 0~1, 사용자 이름과 비슷한 정도
}

/// 읽었지만 해석하지 못한 칸
struct UnreadableCell: Hashable {
    var date: Date
    var rawText: String
}

/// 근무표 인식 결과 전체 (Review 화면이 받는 데이터)
struct ExtractionResult {
    var shifts: [ExtractedShift]           // ← parser: shifts
    var matchedName: String?               // ← parser: match.label
    var nameCandidates: [NameCandidate]    // ← parser: candidates
    var isNameAmbiguous: Bool              // ← parser: ambiguous
    var needsName: Bool                    // ← parser: needsName
    var datesAssumed: Bool                 // 요일만 있어서 날짜를 추정함  ← parser: datesAssumed
    var weekStart: Date?                   // ← parser: weekStart
    var unreadableCells: [UnreadableCell]  // ← parser: issues
}
