import Foundation

enum SampleExtraction {
    /// 카페 A: AM/PM 없는 시간 ("6-1:30"), 비슷한 이름 "Jamie Lee"
    static let cafeA = ExtractionResult(
        shifts: [
            shift(10, 26, from: (6, 0), to: (13, 30), assumed: true, raw: "6-1:30"),
            shift(10, 27, from: (7, 0), to: (14, 0),  assumed: true, raw: "7-2"),
            shift(10, 29, from: (6, 0), to: (12, 0),  assumed: true, raw: "6-12"),
            shift(10, 31, from: (8, 0), to: (16, 0),  assumed: true, raw: "8-4"),
        ],
        matchedName: "Jamie Park",
        nameCandidates: [
            NameCandidate(label: "Jamie Park", score: 1.0),
            NameCandidate(label: "Jamie Lee", score: 0.6),     // 예시값
        ],
        isNameAmbiguous: false,
        needsName: false,
        datesAssumed: false,
        weekStart: nil,
        unreadableCells: []
    )
    
    /// 식당 B: AM/PM 표기됨, 자정 넘는 근무 ("6p-12a")
    static let restaurantB = ExtractionResult(
        shifts: [
            shift(10, 27, from: (17, 0), to: (22, 0), assumed: false, raw: "5p-10p"),
            shift(10, 30, from: (18, 0), to: (0, 0),  assumed: false, raw: "6p-12a"),
            shift(11, 1,  from: (11, 0), to: (16, 0), assumed: false, raw: "11a-4p"),
        ],
        matchedName: "Park, J.",
        nameCandidates: [NameCandidate(label: "Park, J.", score: 0.97)],
        isNameAmbiguous: false,
        needsName: false,
        datesAssumed: false,
        weekStart: nil,
        unreadableCells: []
    )
    
    /// 2026년 날짜 + 시간으로 근무 만들기 (종료가 시작보다 이르면 다음 날)
    private static func shift(
        _ month: Int, _ day: Int,
        from start: (hour: Int, minute: Int),
        to end: (hour: Int, minute: Int)?,
        assumed: Bool,
        raw: String
    ) -> ExtractedShift {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: start.hour, minute: start.minute
        ))!
        
        var endDate: Date? = nil
        if let end {
            var date = calendar.date(from: DateComponents(
                year: 2026, month: month, day: day, hour: end.hour, minute: end.minute
            ))!
            if date <= startDate {
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            endDate = date
        }
        return ExtractedShift(start: startDate, end: endDate, isTimeAssumed: assumed, rawText: raw)
    }
}
