import Foundation

/// 원본 읽기와 전처리 읽기 결과를 합쳐요.
/// 같은 위치의 글자끼리 비교해서 더 믿을 만한 쪽을 남겨요.
enum OCRMerger {
    
    static func merge(plain: [OCRWord], preprocessed: [OCRWord]) -> [OCRWord] {
        var result = plain
        
        for word in preprocessed {
            // 원본에서 가장 많이 겹치는 글자 찾기
            var bestIndex: Int? = nil
            var bestOverlap = 0.0
            for (index, existing) in result.enumerated() {
                let value = overlap(existing, word)
                if value > bestOverlap {
                    bestOverlap = value
                    bestIndex = index
                }
            }
            
            // 겹치는 글자가 없으면 전처리에서만 찾은 글자 → 추가
            guard let index = bestIndex, bestOverlap >= 0.3 else {
                result.append(word)
                continue
            }
            
            let existing = result[index]
            let oldScore = timeScore(existing.text)
            let newScore = timeScore(word.text)
            
            if newScore > oldScore {
                // 전처리 쪽이 더 깔끔한 근무 시간
                result[index] = word
            } else if oldScore == 0 && newScore == 0
                        && Double(word.confidence) >= Double(existing.confidence) - 20 {
                // 둘 다 이름 같은 글자 → 전처리 쪽 (이름을 더 잘 읽어요)
                result[index] = word
            }
        }
        return result
    }
    
    /// 2: 깔끔한 시간 또는 OFF, 1: 숫자는 있지만 불확실, 0: 시간이 아닌 글자
    private static func timeScore(_ raw: String) -> Int {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let off = #"^(off|0ff|휴무?|x|-)$"#
        let clean = #"^\d{1,2}(:?\d{2})?\s*(am|pm|a|p)?\s*([-–~]\s*\d{1,2}(:?\d{2})?\s*(am|pm|a|p)?|[-–~.]?\s*(cl|close))$"#
        
        if matches(text, off) || matches(text, clean) { return 2 }
        
        // 맨 앞 S, $ → 5, G → 6 으로 바꾸면 시간이 되는 경우
        var fixed = text
        if let first = fixed.first {
            if "sS$".contains(first) { fixed = "5" + fixed.dropFirst() }
            else if "gG".contains(first) { fixed = "6" + fixed.dropFirst() }
        }
        if matches(fixed, clean) { return 1 }
        if text.rangeOfCharacter(from: .decimalDigits) != nil { return 1 }
        return 0
    }
    
    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    /// 두 글자 상자가 얼마나 겹치는지 (0~1)
    private static func overlap(_ a: OCRWord, _ b: OCRWord) -> Double {
        let ax0 = Double(a.x0), ay0 = Double(a.y0), ax1 = Double(a.x1), ay1 = Double(a.y1)
        let bx0 = Double(b.x0), by0 = Double(b.y0), bx1 = Double(b.x1), by1 = Double(b.y1)
        
        let width = max(0, min(ax1, bx1) - max(ax0, bx0))
        let height = max(0, min(ay1, by1) - max(ay0, by0))
        let intersection = width * height
        let union = (ax1 - ax0) * (ay1 - ay0) + (bx1 - bx0) * (by1 - by0) - intersection
        return union > 0 ? intersection / union : 0
    }
}
