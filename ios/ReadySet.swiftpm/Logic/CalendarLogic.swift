import Foundation

/// 달력 한 칸 (빈칸이면 date가 nil)
struct MonthGridItem: Identifiable {
    let id: Int        // 칸 번호: 0, 1, 2 ...
    let date: Date?
}

enum CalendarMath {
    /// 그 달의 1일 0시
    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }
    
    /// 몇 달 앞/뒤로 이동
    static func month(byAdding value: Int, to month: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: value, to: month) ?? month
    }
    
    /// 요일 이름: 기기 설정의 주 시작 요일부터 ["Sun", "Mon", ...]
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortWeekdaySymbols      // 항상 일요일부터 시작하는 목록
        let first = calendar.firstWeekday - 1           // 기기 설정의 주 시작 요일 (일요일 = 0)
        return Array(symbols[first...] + symbols[..<first])
    }
    
    /// 한 달 달력의 칸들 (앞쪽 빈칸 + 1일~말일)
    static func monthGrid(for month: Date, calendar: Calendar = .current) -> [MonthGridItem] {
        let start = startOfMonth(for: month, calendar: calendar)
        guard let dayCount = calendar.range(of: .day, in: .month, for: start)?.count else {
            return []
        }
        
        let weekdayOfFirst = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        
        var items: [MonthGridItem] = []
        for index in 0..<leadingBlanks {
            items.append(MonthGridItem(id: index, date: nil))
        }
        for dayOffset in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start)
            items.append(MonthGridItem(id: leadingBlanks + dayOffset, date: date))
        }
        return items
    }
    
    /// 그 날짜가 속한 한 주 (시작 ~ 다음 주 시작)
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
        ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
    }
}

extension CalendarMath {
    /// 날짜(연·월·일) + 시간(시·분)을 하나의 Date로 합치기
    static func combine(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute], from: time)
        let components = DateComponents(
            year: d.year, month: d.month, day: d.day,
            hour: t.hour, minute: t.minute
        )
        return calendar.date(from: components) ?? day
    }
    
    /// 근무 종료 시각: 시작보다 이르거나 같으면 다음 날로
    static func shiftEnd(start: Date, endTime: Date, calendar: Calendar = .current) -> Date {
        let sameDay = combine(day: start, time: endTime, calendar: calendar)
        if sameDay <= start {
            return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
        }
        return sameDay
    }
}
