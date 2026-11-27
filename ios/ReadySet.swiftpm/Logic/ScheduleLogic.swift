import Foundation

/// 근무 목록에 대한 계산
enum ShiftSchedule {
    /// 아직 시작하지 않은 근무들을 빠른 순으로 정렬
    static func futureShifts(in shifts: [Shift], after now: Date) -> [Shift] {
        shifts
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
    }
    
    /// 특정 날짜에 시작하는 근무가 있는지
    static func hasShift(in shifts: [Shift], on date: Date, calendar: Calendar = .current) -> Bool {
        shifts.contains { calendar.isDate($0.start, inSameDayAs: date) }
    }
}

/// 알람 및 리마인더 시간 계산 (앱 전체 설정 기준)
enum AlarmCalculator {
    /// 기상 알람 시간 = 근무 시작 − 기상 준비 시간
    static func wakeUpTime(for shift: Shift, settings: AlarmSettings) -> Date {
        shift.start.addingTimeInterval(-Double(settings.wakeUpMinutesBefore) * 60)
    }
    
    /// 모든 리마인더 시간 (빠른 순). 리마인더가 꺼져 있으면 빈 목록
    static func reminderTimes(for shift: Shift, settings: AlarmSettings) -> [Date] {
        guard settings.remindersEnabled else { return [] }
        return settings.reminderMinutesBefore
            .map { shift.start.addingTimeInterval(-Double($0) * 60) }
            .sorted()
    }
    
    /// 아직 지나지 않은 가장 가까운 리마인더 (없으면 nil)
    static func nextReminder(for shift: Shift, settings: AlarmSettings, after now: Date) -> Date? {
        reminderTimes(for: shift, settings: settings).first { $0 > now }
    }
}

/// 하루치 근무 묶음 (List 화면에서 날짜별로 묶을 때 사용)
struct DayShifts: Identifiable {
    let date: Date          // 그날 0시
    let shifts: [Shift]
    var id: Date { date }
}

extension ShiftSchedule {
    /// 특정 날짜에 시작하는 근무들 (시간순)
    static func shifts(in shifts: [Shift], on date: Date, calendar: Calendar = .current) -> [Shift] {
        shifts
            .filter { calendar.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }
    
    /// 특정 기간 안에 시작하는 근무들 (시간순)
    static func shifts(in shifts: [Shift], during interval: DateInterval) -> [Shift] {
        shifts
            .filter { $0.start >= interval.start && $0.start < interval.end }
            .sorted { $0.start < $1.start }
    }
    
    /// 근무들을 날짜별로 묶기
    static func groupedByDay(_ shifts: [Shift], calendar: Calendar = .current) -> [DayShifts] {
        let groups = Dictionary(grouping: shifts) { calendar.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { day in
            DayShifts(date: day, shifts: (groups[day] ?? []).sorted { $0.start < $1.start })
        }
    }
}

extension ShiftSchedule {
    /// 특정 날짜에 근무하는 직장들 (중복 없이, 근무 시간순)
    static func workplaces(in shifts: [Shift], on date: Date, calendar: Calendar = .current) -> [Workplace] {
        var seenIDs = Set<UUID>()
        return self.shifts(in: shifts, on: date, calendar: calendar)
            .map { $0.workplace }
            .filter { seenIDs.insert($0.id).inserted }
    }
}
