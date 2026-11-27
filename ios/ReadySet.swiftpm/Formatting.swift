import Foundation

extension Date {
    /// 시간만: "6:00 AM" 또는 "06:00" (기기 설정에 따름)
    var shortTimeText: String {
        formatted(date: .omitted, time: .shortened)
    }
    
    /// 요일 + 날짜: "Mon, Oct 26"
    var shortDayText: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

extension Shift {
    /// 근무 시간 범위: "6:00 AM – 1:30 PM"
    var timeRangeText: String {
        "\(start.shortTimeText) – \(end.shortTimeText)"
    }
}

extension Date {
    /// "Today, 9:00 AM" / "Tonight, 8:00 PM" / "Tomorrow, 6:00 AM" / "Mon, Oct 26, 6:00 AM"
    func relativeDayTimeText(now: Date = .now, calendar: Calendar = .current) -> String {
        let dayText: String
        if calendar.isDate(self, inSameDayAs: now) {
            dayText = calendar.component(.hour, from: self) >= 18 ? "Tonight" : "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(self, inSameDayAs: tomorrow) {
            dayText = "Tomorrow"
        } else {
            dayText = shortDayText
        }
        return "\(dayText), \(shortTimeText)"
    }
}

extension Date {
    /// "Monday, October 26"
    var longDayText: String {
        formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    
    /// "October 2026"
    var monthYearText: String {
        formatted(.dateTime.month(.wide).year())
    }
}

enum TextFormat {
    /// "1 shift" / "3 shifts"
    static func shiftCount(_ count: Int) -> String {
        count == 1 ? "1 shift" : "\(count) shifts"
    }
    
    /// "Oct 25 – Oct 31, 2026"
    static func weekRange(_ week: DateInterval, calendar: Calendar = .current) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let startText = week.start.formatted(.dateTime.month(.abbreviated).day())
        let endText = lastDay.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText) – \(endText)"
    }
}

extension ExtractedShift {
    /// "6:00 AM – 1:30 PM" / "6:00 PM – 12:00 AM +1" / "4:00 PM – Close"
    var timeRangeText: String {
        guard let end else {
            return "\(start.shortTimeText) – Close"
        }
        let base = "\(start.shortTimeText) – \(end.shortTimeText)"
        return isOvernight ? base + " +1" : base
    }
}

extension TextFormat {
    /// 근무 길이: "12 hr" / "7 hr 30 min" / "45 min"
    static func duration(from start: Date, to end: Date) -> String {
        let totalMinutes = Int(end.timeIntervalSince(start) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default:     return "\(hours) hr \(minutes) min"
        }
    }
}

extension TextFormat {
    /// 긴 표기: "2 hours" / "1 hour 30 minutes" / "45 minutes"
    static func longDuration(minutes total: Int) -> String {
        let hours = total / 60
        let minutes = total % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minuteText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        
        switch (hours, minutes) {
        case (0, _): return minuteText
        case (_, 0): return hourText
        default:     return "\(hourText) \(minuteText)"
        }
    }
}
