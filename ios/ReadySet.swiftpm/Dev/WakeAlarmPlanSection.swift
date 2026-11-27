import SwiftUI

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
