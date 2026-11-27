import Foundation

/// 테스트용으로 "이미 읽었다고 가정한" 근무표들
enum SampleSchedules {
    /// A_cafe_weekly_grid.png (Mon 10/26 ~ Sun 11/1)
    static var cafeA: RecognizedSchedule {
        RecognizedSchedule { names in
            gridResult(rows: cafeARows, firstDay: (month: 10, day: 26), names: names)
        }
    }
    
    /// 식당 B: 이름과 상관없이 고정 결과
    static var restaurantB: RecognizedSchedule {
        .fixed(SampleExtraction.restaurantB)
    }
    
    // MARK: - 카페 A 근무표 내용 (월~일)
    
    private static var cafeARows: [(label: String, cells: [String])] {
        [
            ("Sarah Thompson", ["6-12", "6-12", "OFF", "OFF", "12-6", "8-4", "8-4"]),
            ("Jamie Lee",      ["12-6", "OFF", "6-1:30", "6-1:30", "OFF", "12-6", "OFF"]),
            ("Jamie Park",     ["6-1:30", "7-2", "OFF", "6-12", "OFF", "8-4", "OFF"]),
            ("Daniel Cho",     ["OFF", "12-6", "12-6", "OFF", "6-1:30", "OFF", "12-6"]),
            ("Priya Nair",     ["1:30-8", "1:30-8", "1:30-8", "12-6", "OFF", "OFF", "8-4"]),
            ("Marcus Bell",    ["OFF", "6-12", "6-12", "1:30-8", "1:30-8", "4-8", "OFF"]),
        ]
    }
    
    // MARK: - 친구 parser의 마지막 단계를 흉내
    
    /// 줄마다 이름 점수를 매기고, 가장 잘 맞는 사람의 근무를 결과로 만듦
    private static func gridResult(
        rows: [(label: String, cells: [String])],
        firstDay: (month: Int, day: Int),
        names: [String]
    ) -> ExtractionResult {
        let candidates = rows.map {
            NameCandidate(label: $0.label, score: NameMatching.score(label: $0.label, against: names))
        }
        let (match, isAmbiguous) = NameMatching.pickMatch(candidates)
        
        var shifts: [ExtractedShift] = []
        let calendar = Calendar.current
        if let match,
           let row = rows.first(where: { $0.label == match.label }),
           let firstDate = calendar.date(from: DateComponents(year: 2026, month: firstDay.month, day: firstDay.day)) {
            for (offset, cell) in row.cells.enumerated() {
                guard let day = calendar.date(byAdding: .day, value: offset, to: firstDate) else { continue }
                if let shift = parseCell(cell, on: day) {
                    shifts.append(shift)
                }
            }
        }
        
        return ExtractionResult(
            shifts: shifts,
            matchedName: match?.label,
            nameCandidates: candidates.sorted { $0.score > $1.score },
            isNameAmbiguous: isAmbiguous,
            needsName: match == nil,
            datesAssumed: false,
            weekStart: nil,
            unreadableCells: []
        )
    }
    
    /// AM/PM 없는 "6-1:30" 형식 해석 (friend's parseShift의 규칙과 같음)
    /// 시작: 5~11시는 AM, 그 외(12, 1~4시)는 PM / 종료: 시작 뒤에 오는 가장 가까운 시각
    private static func parseCell(_ raw: String, on day: Date) -> ExtractedShift? {
        let parts = raw.split(separator: "-")
        guard parts.count == 2,
              let startRaw = minutesOnClock(parts[0]),
              let endRaw = minutesOnClock(parts[1])
        else { return nil }   // "OFF" 등은 근무 아님
        
        let startHour = startRaw / 60
        let start = (5...11).contains(startHour) ? startRaw % 720 : startRaw % 720 + 720
        
        let end12 = endRaw % 720
        func gap(_ minutes: Int) -> Int { ((minutes - start) % 1440 + 1440) % 1440 }
        let end = [end12, end12 + 720].filter { gap($0) > 0 }.min { gap($0) < gap($1) } ?? end12
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let startDate = calendar.date(byAdding: .minute, value: start, to: dayStart),
              var endDate = calendar.date(byAdding: .minute, value: end, to: dayStart)
        else { return nil }
        if endDate <= startDate {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }
        return ExtractedShift(start: startDate, end: endDate, isTimeAssumed: true, rawText: raw)
    }
    
    /// "6" → 360, "1:30" → 90 (12시간제 시계의 분)
    private static func minutesOnClock(_ text: Substring) -> Int? {
        let pieces = text.split(separator: ":")
        guard let hourText = pieces.first, let hour = Int(hourText), (1...12).contains(hour) else { return nil }
        let minute = pieces.count > 1 ? (Int(pieces[1]) ?? 0) : 0
        return hour * 60 + minute
    }
}
