import Foundation
import SwiftData

/// 기기에 저장되는 직장
@Model
final class WorkplaceRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameOnSchedule: String
    var aliases: [String]
    var colorName: String      // WorkplaceColor의 이름 ("orange")
    var isArchived: Bool       // 삭제한 직장: 목록에선 숨기고, 기존 근무를 위해 보관
    var createdAt: Date        // 목록 순서용
    
    init(from workplace: Workplace) {
        self.id = workplace.id
        self.name = workplace.name
        self.nameOnSchedule = workplace.nameOnSchedule
        self.aliases = workplace.aliases
        self.colorName = workplace.color.rawValue
        self.isArchived = false
        self.createdAt = .now
    }
    
    func update(from workplace: Workplace) {
        name = workplace.name
        nameOnSchedule = workplace.nameOnSchedule
        aliases = workplace.aliases
        colorName = workplace.color.rawValue
    }
}

/// 기기에 저장되는 근무
@Model
final class ShiftRecord {
    @Attribute(.unique) var id: UUID
    var start: Date
    var end: Date
    var workplace: WorkplaceRecord?    // 이 근무의 직장 (연결)
    
    init(from shift: Shift, workplace: WorkplaceRecord?) {
        self.id = shift.id
        self.start = shift.start
        self.end = shift.end
        self.workplace = workplace
    }
}

/// 저장된 직장 → 화면용 Workplace
extension Workplace {
    init(record: WorkplaceRecord) {
        self.init(
            id: record.id,
            name: record.name,
            nameOnSchedule: record.nameOnSchedule,
            aliases: record.aliases,
            color: WorkplaceColor(rawValue: record.colorName) ?? .blue
        )
    }
}
