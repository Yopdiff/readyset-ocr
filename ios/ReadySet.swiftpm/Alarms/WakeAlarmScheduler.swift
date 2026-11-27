import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
#endif

/// Wake-up 알람을 근무·설정에 맞게 다시 예약해요.
/// 알람 설명 문구(Info.plist)가 없으면(= Playgrounds) 아무것도 하지 않아요.
enum WakeAlarmSync {
    static func sync(shifts: [Shift], settings: AlarmSettings) async {
        guard AlarmKitCheck.hasUsageDescription else { return }
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let plan = WakeAlarmPlanner.plan(shifts: shifts, settings: settings)
            await WakeAlarmScheduler.apply(plan)
        }
#endif
    }
}

/// 지금 예약돼 있는 알람의 내용 (알람 ID = 근무 ID → 내용 요약)
/// 바뀐 알람만 다시 예약하려고 기기에 기억해 둬요.
enum ScheduledAlarmLog {
    private static let key = "scheduledWakeAlarms"

    static func load() -> [UUID: String] {
        let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { id, value in
            UUID(uuidString: id).map { ($0, value) }
        })
    }

    static func save(_ log: [UUID: String]) {
        let raw = Dictionary(uniqueKeysWithValues: log.map { ($0.key.uuidString, $0.value) })
        UserDefaults.standard.set(raw, forKey: key)
    }

    /// 이 값이 같으면 알람을 다시 예약할 필요가 없어요 (시각, 직장 이름, 근무 시작이 같음)
    static func fingerprint(_ alarm: PlannedWakeAlarm) -> String {
        "\(alarm.fireDate.timeIntervalSince1970)|\(alarm.workplaceName)|\(alarm.shiftStart.timeIntervalSince1970)"
    }
}

#if canImport(AlarmKit)
/// 알람에 붙일 추가 정보 (지금은 비어 있음)
@available(iOS 26.0, *)
struct ShiftAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
enum WakeAlarmScheduler {
    /// 계획과 지금 예약된 알람을 비교해서, 바뀐 것만 취소·예약해요.
    /// (예전에는 앱을 열 때마다 전부 지우고 다시 예약해서, 그 사이에 알람이 비거나 중간에 실패하면 사라질 수 있었어요.)
    static func apply(_ plan: [PlannedWakeAlarm]) async {
        let manager = AlarmManager.shared

        // 1. 권한: 예약할 알람이 생겼을 때 처음 물어봐요 (앱을 켜자마자 묻지 않게)
        if manager.authorizationState == .notDetermined {
            guard !plan.isEmpty else { return }
            _ = try? await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { return }

        let wanted = Dictionary(plan.map { ($0.shiftID, $0) }, uniquingKeysWith: { first, _ in first })
        let existing = Set(((try? manager.alarms) ?? []).map(\.id))
        var log = ScheduledAlarmLog.load().filter { existing.contains($0.key) }   // 이미 울렸거나 사라진 알람은 잊기

        // 2. 더 이상 필요 없거나 내용이 바뀐 알람 취소
        for id in existing {
            if let alarm = wanted[id], log[id] == ScheduledAlarmLog.fingerprint(alarm) { continue }
            try? manager.cancel(id: id)
            log[id] = nil
        }

        // 3. 아직 예약 안 된 알람만 예약 (알람 ID = 근무 ID)
        for alarm in plan where log[alarm.shiftID] == nil {
            do {
                _ = try await manager.schedule(id: alarm.shiftID, configuration: configuration(for: alarm))
                log[alarm.shiftID] = ScheduledAlarmLog.fingerprint(alarm)
            } catch {
                print("⚠️ Could not schedule wake-up alarm: \(error)")
            }
        }
        ScheduledAlarmLog.save(log)
    }

    private static func configuration(for item: PlannedWakeAlarm) -> AlarmManager.AlarmConfiguration<ShiftAlarmMetadata> {
        let time = item.shiftStart.formatted(date: .omitted, time: .shortened)
        let alert = AlarmPresentation.Alert(
            title: "\(item.workplaceName) shift at \(time)",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
            secondaryButton: nil,
            secondaryButtonBehavior: nil)

        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: ShiftAlarmMetadata(),
            tintColor: AppColor.primary)

        return .alarm(schedule: .fixed(item.fireDate), attributes: attributes)
    }
}
#endif
