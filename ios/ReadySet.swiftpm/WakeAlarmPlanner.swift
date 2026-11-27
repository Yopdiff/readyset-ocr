import SwiftUI

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
enum WakeAlarmPlanner {
    /// 며칠 앞까지 예약할지
    static let lookAheadDays = 14
    /// 앞 근무가 끝난 뒤 이 시간 안에 울릴 알람은 건너뜀 (이미 깨어 있음)
    static let minimumGapHours = 4.0
    
    static func plan(shifts: [Shift], settings: AlarmSettings, now: Date = .now) -> [PlannedWakeAlarm] {
        let sorted = shifts.sorted { $0.start < $1.start }
        let horizon = now.addingTimeInterval(Double(lookAheadDays) * 24 * 3600)
        var result: [PlannedWakeAlarm] = []
        
        for (index, shift) in sorted.enumerated() {
            let wakeTime = shift.start.addingTimeInterval(-Double(settings.wakeUpMinutesBefore) * 60)
            guard wakeTime > now, wakeTime <= horizon else { continue }
            
            // 이 근무보다 앞선 근무 중 가장 늦게 끝나는 시각
            if let previousEnd = sorted[..<index].map(\.end).max(),
               wakeTime.timeIntervalSince(previousEnd) < minimumGapHours * 3600 {
                continue
            }
            
            result.append(PlannedWakeAlarm(
                shiftID: shift.id,
                fireDate: wakeTime,
                workplaceName: shift.workplace.name,
                shiftStart: shift.start))
        }
        return result
    }
}

/// 개발용: Reminder test 화면에 계획된 알람 목록 보여주기 (TODO: 출시 전 삭제)
struct WakeAlarmPlanSection: View {
    @EnvironmentObject private var store: ShiftStore
    
    var body: some View {
        let plan = WakeAlarmPlanner.plan(shifts: store.shifts, settings: store.alarmSettings)
        
        Section("Planned wake-up alarms (\(plan.count))") {
            if plan.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            }
            ForEach(plan) { alarm in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.fireDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                    Text("\(alarm.workplaceName) · shift at \(alarm.shiftStart.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
