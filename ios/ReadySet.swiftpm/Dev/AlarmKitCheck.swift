import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

/// 개발용: AlarmKit을 쓸 수 있는 환경인지 확인 (TODO: 출시 전 삭제)
enum AlarmKitCheck {
    /// Playgrounds가 AlarmKit을 알고 있는지
    static var canImport: Bool {
#if canImport(AlarmKit)
        return true
#else
        return false
#endif
    }
    
    /// 앱 설정에 알람 권한 설명 문구가 있는지
    static var hasUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSAlarmKitUsageDescription") != nil
    }
}
