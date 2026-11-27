import Foundation

/// 직장 구분 색상 (데이터에는 이름만 저장)
enum WorkplaceColor: String, CaseIterable, Hashable {
    case blue, green, orange, purple, pink, teal
}

/// 직장 (예: Café A)
struct Workplace: Identifiable, Hashable {
    let id: UUID
    var name: String              // 직장 이름: "Café A"
    var nameOnSchedule: String    // 기본 이름 (Manage Workplaces의 Employee name): "Taylor"
    var aliases: [String]         // Review에서 사용자가 고른 이름표들 (자동 매칭용, 화면에는 안 보임)
    var color: WorkplaceColor     // 구분 색상
    
    init(
        id: UUID = UUID(),
        name: String,
        nameOnSchedule: String = "",
        aliases: [String] = [],
        color: WorkplaceColor = .blue
    ) {
        self.id = id
        self.name = name
        self.nameOnSchedule = nameOnSchedule
        self.aliases = aliases
        self.color = color
    }
}

/// 근무 1회
struct Shift: Identifiable, Hashable {
    let id: UUID
    var workplace: Workplace
    var start: Date               // 근무 시작 (날짜 + 시간)
    var end: Date                 // 근무 종료 (밤샘 근무면 다음 날)
    
    init(id: UUID = UUID(), workplace: Workplace, start: Date, end: Date) {
        self.id = id
        self.workplace = workplace
        self.start = start
        self.end = end
    }
}

/// 알람 소리 선택지
enum AlarmSound: String, CaseIterable, Hashable, Codable {
    case standard, gentleMorning, chime, classicAlarm, digitalBeep
    
    var displayName: String {
        switch self {
        case .standard:      "Default"
        case .gentleMorning: "Gentle Morning"
        case .chime:         "Chime"
        case .classicAlarm:  "Classic Alarm"
        case .digitalBeep:   "Digital Beep"
        }
    }
}

/// 앱 전체 알람·알림 설정 (Settings 탭)
struct AlarmSettings: Hashable, Codable {
    var wakeUpMinutesBefore = 120                 // 기상 알람: 근무 몇 분 전
    var sound: AlarmSound = .standard             // 기상 알람 소리
    var remindersEnabled = true                   // 리마인더 켜기/끄기
    var reminderMinutesBefore: [Int] = [12 * 60]  // 리마인더: 근무 몇 분 전 (최대 3개)
}
