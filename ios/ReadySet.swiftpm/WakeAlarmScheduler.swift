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

#if canImport(AlarmKit)
/// 알람에 붙일 추가 정보 (지금은 비어 있음)
@available(iOS 26.0, *)
struct ShiftAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
enum WakeAlarmScheduler {
    static func apply(_ plan: [PlannedWakeAlarm]) async {
        let manager = AlarmManager.shared
        
        // 1. 권한 (처음이면 물어보기)
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { return }
        
        // 2. 우리 앱이 예약한 알람 전부 취소
        for alarm in (try? manager.alarms) ?? [] {
            try? manager.cancel(id: alarm.id)
        }
        
        // 3. 계획대로 다시 예약
        for item in plan {
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
            
            let configuration = AlarmManager.AlarmConfiguration<ShiftAlarmMetadata>.alarm(
                schedule: .fixed(item.fireDate),
                attributes: attributes)
            
            _ = try? await manager.schedule(id: UUID(), configuration: configuration)
        }
    }
}
#endif
