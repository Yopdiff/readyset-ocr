import Foundation

/// 예약할 Wake-up 알람 하나
struct PlannedWakeAlarm: Identifiable, Hashable {
    let shiftID: UUID
    let fireDate: Date          // 알람이 울릴 시각
    let workplaceName: String
    let shiftStart: Date
    var id: UUID { shiftID }
}

/// 근무 목록과 설정으로 Wake-up 알람 계획을 만들어요.
/// (AlarmKit 없이 계산만 해서 Playgrounds에서도 테스트 가능)
/// 화면(Home, Shifts)도 이 규칙을 그대로 써서, 보여주는 알람 = 실제로 예약되는 알람이 되게 해요.
enum WakeAlarmPlanner {
    /// 며칠 앞까지 예약할지
    static let lookAheadDays = 14

    /// 앞 근무가 끝나고 이 시간 안에 울릴 알람은 건너뜀 (방금 퇴근해서 아직 깨어 있음)
    /// 예전 규칙(4시간)은 너무 길었어요: 23시 퇴근 → 새벽 2시 기상이면 그 사이에 잠들 수 있어요.
    static let awakeAfterShift: TimeInterval = 60 * 60

    /// 이 근무의 Wake-up 알람 시각. 알람이 없으면 nil
    /// - 알람 시각이 이미 지남
    /// - 알람 시각에 다른 근무 중이거나, 그 근무가 끝난 지 1시간이 안 됨 (깨어 있음)
    static func wakeUpTime(for shift: Shift, among shifts: [Shift], settings: AlarmSettings, now: Date = .now) -> Date? {
        let wakeTime = AlarmCalculator.wakeUpTime(for: shift, settings: settings)
        guard wakeTime > now else { return nil }

        let isAwake = shifts.contains { other in
            other.id != shift.id
            && other.start < shift.start
            && other.start <= wakeTime
            && wakeTime < other.end.addingTimeInterval(awakeAfterShift)
        }
        return isAwake ? nil : wakeTime
    }

    static func plan(shifts: [Shift], settings: AlarmSettings, now: Date = .now) -> [PlannedWakeAlarm] {
        let horizon = now.addingTimeInterval(Double(lookAheadDays) * 24 * 3600)

        return shifts
            .sorted { $0.start < $1.start }
            .compactMap { shift in
                guard let fireDate = wakeUpTime(for: shift, among: shifts, settings: settings, now: now),
                      fireDate <= horizon
                else { return nil }
                return PlannedWakeAlarm(
                    shiftID: shift.id,
                    fireDate: fireDate,
                    workplaceName: shift.workplace.name,
                    shiftStart: shift.start)
            }
    }
}
