import Foundation

/// 근무표의 이름표가 사용자 이름과 얼마나 비슷한지 계산
/// (friend's parser.js: letters, levenshtein, nameVariants, scoreName, pickMatch)
enum NameMatching {
    /// 이 점수 이상이면 같은 사람으로 봄
    static let threshold = 0.75
    
    /// 글자만 남기고 소문자로: "Park, J." → "parkj"
    static func letters(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter })
    }
    
    /// 한 문자열을 다른 문자열로 바꾸는 데 필요한 최소 편집 횟수 (추가·삭제·교체)
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
    
    /// 0~1: 1이면 완전히 같음
    static func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return 1 - Double(levenshtein(a, b)) / Double(max(a.count, b.count))
    }
    
    /// 근무표에 흔히 쓰이는 이름 표기들과 가중치 (1 = 전체 이름만큼 확실)
    static func variants(of name: String) -> [(text: String, weight: Double)] {
        let parts = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "." || $0 == "-" })
            .map { letters(String($0)) }
            .filter { !$0.isEmpty }
        guard let first = parts.first, let last = parts.last else { return [] }
        if parts.count == 1 { return [(first, 1)] }
        
        let firstInitial = String(first.prefix(1))
        let lastInitial = String(last.prefix(1))
        return [
            (parts.joined(), 1),
            (first + last, 1),
            (last + first, 1),
            (firstInitial + last, 0.97),   // J. Park
            (last + firstInitial, 0.97),   // Park, J.
            (first + lastInitial, 0.9),    // Jamie P.
            (last, 0.8),
            (first, 0.8),
        ]
    }
    
    /// 이름표 하나가 사용자의 이름들 중 하나와 얼마나 맞는지 (0~1)
    static func score(label: String, against names: [String]) -> Double {
        let candidate = letters(label)
        guard candidate.count >= 2 else { return 0 }
        var best = 0.0
        for name in names {
            for variant in variants(of: name) {
                best = max(best, similarity(candidate, variant.text) * variant.weight)
            }
        }
        return best
    }
    
    /// 가장 잘 맞는 후보와, 확신이 낮은지 여부
    static func pickMatch(_ candidates: [NameCandidate]) -> (match: NameCandidate?, isAmbiguous: Bool) {
        let sorted = candidates.sorted { $0.score > $1.score }
        guard let best = sorted.first, best.score >= threshold else {
            return (nil, false)
        }
        let second = sorted.dropFirst().first
        let closeSecond = second.map { $0.score >= threshold && best.score - $0.score < 0.1 } ?? false
        return (best, best.score < 0.9 || closeSecond)
    }
}
