import Foundation
import JavaScriptCore

// MARK: - parser.js가 돌려주는 결과 (JSON 모양 그대로)

struct ParserOutput: Decodable {
    struct ParsedShift: Decodable {
        let date: String      // "2026-10-26"
        let start: String     // "06:00"
        let end: String?      // "13:30" (마감이면 null)
        let assumed: Bool?    // AM/PM을 추정했는지
        let raw: String?      // 근무표 원문 "6-1:30"
    }
    struct Candidate: Decodable {
        let label: String
        let score: Double
    }
    struct Issue: Decodable {
        let date: String
        let raw: String
    }
    
    let layout: String            // "grid", "transposed", "list", "none"
    let shifts: [ParsedShift]
    let issues: [Issue]
    let match: Candidate?
    let ambiguous: Bool
    let candidates: [Candidate]
    let needsName: Bool
    let datesAssumed: Bool
    let weekStart: String?
}

// MARK: - parser.js 실행기 (JavaScriptCore)

/// 앱 안에서 parser.js를 실행. 한 번만 불러와서 계속 사용
final class ScheduleParser: @unchecked Sendable {
    static let shared = ScheduleParser()
    
    private let context: JSContext?
    private let lock = NSLock()   // 한 번에 하나씩만 실행
    
    private init() {
        let context = JSContext()
        context?.exceptionHandler = { _, exception in
            print("⚠️ parser.js error: \(exception?.toString() ?? "unknown")")
        }
        context?.evaluateScript(ParserScript.source)
        
        // Swift ↔ JavaScript 사이를 JSON 글자로 주고받는 작은 도우미
        context?.evaluateScript("""
        function __extract(wordsJSON, optsJSON) {
          var opts = JSON.parse(optsJSON);
          opts.refDate = new Date(opts.refDate);
          if (!opts.weekOf) { delete opts.weekOf; }
          return JSON.stringify(ReadySet.extractShifts(JSON.parse(wordsJSON), opts));
        }
        """)
        self.context = context
    }
    
    /// parser.js가 제대로 불러와졌는지 (붙여 넣기 확인용)
    var isReady: Bool {
        context?.objectForKeyedSubscript("ReadySet")?.isObject ?? false
    }
    
    /// OCR 단어 + 찾을 이름 → parser.js 결과
    func extract(words: [OCRWord], names: [String], weekOf: Date? = nil, now: Date = .now) -> ParserOutput? {
        struct Options: Encodable {
            let names: [String]
            let refDate: String
            let weekOf: String?
        }
        let options = Options(
            names: names,
            refDate: ISO8601DateFormatter().string(from: now),
            weekOf: weekOf.map(Self.dayString)
        )
        
        guard let wordsData = try? JSONEncoder().encode(words),
              let optionsData = try? JSONEncoder().encode(options),
              let wordsJSON = String(data: wordsData, encoding: .utf8),
              let optionsJSON = String(data: optionsData, encoding: .utf8)
        else { return nil }
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let function = context?.objectForKeyedSubscript("__extract"),
              let output = function.call(withArguments: [wordsJSON, optionsJSON]),
              output.isString,
              let data = output.toString().data(using: .utf8)
        else { return nil }
        
        return try? JSONDecoder().decode(ParserOutput.self, from: data)
    }
    
    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - parser.js 결과 → 앱의 ExtractionResult

extension ParserOutput {
    func toExtractionResult(calendar: Calendar = .current) -> ExtractionResult {
        /// "2026-10-26" → 그날 0시
        func day(_ text: String) -> Date? {
            let parts = text.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
        /// "06:00" + 날짜 → 그 시각
        func time(_ text: String, on day: Date) -> Date? {
            let parts = text.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }
        
        let converted: [ExtractedShift] = shifts.compactMap { parsed in
            guard let shiftDay = day(parsed.date), let start = time(parsed.start, on: shiftDay) else { return nil }
            var end: Date? = nil
            if let endText = parsed.end, let sameDayEnd = time(endText, on: shiftDay) {
                // 종료가 시작보다 이르거나 같으면 다음 날 (밤샘 근무) — 직접 입력할 때와 같은 규칙
                end = CalendarMath.shiftEnd(start: start, endTime: sameDayEnd, calendar: calendar)
            }
            return ExtractedShift(
                start: start,
                end: end,
                isTimeAssumed: parsed.assumed ?? false,
                rawText: parsed.raw ?? ""
            )
        }
        
        return ExtractionResult(
            shifts: converted,
            matchedName: match?.label,
            nameCandidates: candidates.map { NameCandidate(label: $0.label, score: $0.score) },
            isNameAmbiguous: ambiguous,
            needsName: needsName,
            datesAssumed: datesAssumed,
            weekStart: weekStart.flatMap(day),
            unreadableCells: issues.compactMap { issue in
                day(issue.date).map { UnreadableCell(date: $0, rawText: issue.raw) }
            }
        )
    }
}

extension ExtractionResult {
    /// 아무것도 찾지 못한 결과
    static var empty: ExtractionResult {
        ExtractionResult(
            shifts: [], matchedName: nil, nameCandidates: [],
            isNameAmbiguous: false, needsName: false, datesAssumed: false,
            weekStart: nil, unreadableCells: []
        )
    }
}

// MARK: - 실제 사진 → RecognizedSchedule

extension RecognizedSchedule {
    /// Vision이 읽은 단어들로 만든 근무표. 이름을 주면 parser.js로 근무를 찾음
    static func fromOCR(words: [OCRWord]) -> RecognizedSchedule {
        RecognizedSchedule { names in
            ScheduleParser.shared.extract(words: words, names: names)?.toExtractionResult() ?? .empty
        }
    }
}
