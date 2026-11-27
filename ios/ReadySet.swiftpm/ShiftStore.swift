import SwiftUI
import SwiftData

/// 앱 전체가 함께 쓰는 근무·직장·설정 저장소
/// 화면은 이 저장소만 보고, 실제 저장(SwiftData·UserDefaults)은 이 안에서 처리
@MainActor
final class ShiftStore: ObservableObject {
    @Published private(set) var shifts: [Shift]
    @Published private(set) var workplaces: [Workplace]       // 보관(삭제)된 직장은 제외
    @Published var alarmSettings: AlarmSettings {
        didSet { saveAlarmSettings() }
    }
    
    private let container: ModelContainer?                    // nil이면 저장 안 함 (프리뷰용)
    private var context: ModelContext? { container?.mainContext }
    private var syncTask: Task<Void, Never>?                  // 리마인더 다시 맞추는 작업
    
    // MARK: - 만들기
    
    /// 메모리에만 있는 저장소 (프리뷰·테스트용, 저장 안 함)
    init(shifts: [Shift] = [], workplaces: [Workplace] = [], alarmSettings: AlarmSettings = AlarmSettings()) {
        self.container = nil
        self.shifts = shifts
        self.workplaces = workplaces
        self.alarmSettings = alarmSettings
    }
    
    /// 기기에 저장된 데이터로 시작
    private init(container: ModelContainer) {
        self.container = container
        let context = container.mainContext
        
        let workplaceRecords = (try? context.fetch(
            FetchDescriptor<WorkplaceRecord>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        let shiftRecords = (try? context.fetch(
            FetchDescriptor<ShiftRecord>(sortBy: [SortDescriptor(\.start)])
        )) ?? []
        
        self.workplaces = workplaceRecords
            .filter { !$0.isArchived }
            .map { Workplace(record: $0) }
        self.shifts = shiftRecords.compactMap { record in
            guard let workplace = record.workplace else { return nil }
            return Shift(id: record.id, workplace: Workplace(record: workplace), start: record.start, end: record.end)
        }
        self.alarmSettings = Self.loadAlarmSettings()
        
        scheduleReminderSync()    // 앱을 켤 때 한 번 맞추기
    }
    
    /// 실제 앱용: 기기 저장소를 열고, 실패하면 메모리 저장소로 대신 시작
    static func persistent() -> ShiftStore {
            NotificationDelegate.shared.activate()
        do {
            let container = try ModelContainer(for: WorkplaceRecord.self, ShiftRecord.self)
            return ShiftStore(container: container)
        } catch {
            print("⚠️ Could not open saved data: \(error)")
            return ShiftStore()
        }
    }
    
    /// 프리뷰용 테스트 데이터
    static var sample: ShiftStore {
        ShiftStore(shifts: SampleData.shifts, workplaces: [SampleData.cafe, SampleData.restaurant])
    }
    
    // MARK: - 이름
    
    /// 처음 보는 근무표에서 "추천"할 때 쓸 기본 이름들
    func suggestionNames(for workplace: Workplace?) -> [String] {
        let names = workplace.map { [$0.nameOnSchedule] } ?? workplaces.map(\.nameOnSchedule)
        return names.filter { !$0.isEmpty }
    }
    
    /// Review에서 확인된 이름표를 직장에 기억 (이미 있으면 건너뜀)
    func addAlias(_ label: String, to workplaceID: UUID) {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty,
              var workplace = workplaces.first(where: { $0.id == workplaceID }),
              !workplace.aliases.contains(where: { isSameName($0, label) })
        else { return }
        
        workplace.aliases.append(label)
        updateWorkplace(workplace)
    }
    
    private func isSameName(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
    
    // MARK: - 직장
    
    @discardableResult
    func addWorkplace(name: String, nameOnSchedule: String) -> Workplace {
        let workplace = Workplace(name: name, nameOnSchedule: nameOnSchedule, color: nextAvailableColor)
        insert(workplace)
        return workplace
    }
    
    private func insert(_ workplace: Workplace) {
        workplaces.append(workplace)
        context?.insert(WorkplaceRecord(from: workplace))
        persist()
    }
    
    /// 직장 정보 수정 (그 직장의 근무에도 반영)
    func updateWorkplace(_ workplace: Workplace) {
        if let index = workplaces.firstIndex(where: { $0.id == workplace.id }) {
            workplaces[index] = workplace
        }
        for i in shifts.indices where shifts[i].workplace.id == workplace.id {
            shifts[i].workplace = workplace
        }
        workplaceRecord(workplace.id)?.update(from: workplace)
        persist()
    }
    
    /// 직장 삭제: 목록에서 숨기고 보관. 이미 등록된 근무는 그대로 남김
    func deleteWorkplace(_ id: UUID) {
        workplaces.removeAll { $0.id == id }
        workplaceRecord(id)?.isArchived = true
        persist()
    }
    
    private var nextAvailableColor: WorkplaceColor {
        let used = Set(workplaces.map(\.color))
        return WorkplaceColor.allCases.first { !used.contains($0) }
        ?? WorkplaceColor.allCases[workplaces.count % WorkplaceColor.allCases.count]
    }
    
    // MARK: - 근무
    
    /// 근무 추가 (같은 직장·같은 시간 근무는 건너뜀). 실제로 추가된 개수를 돌려줌
    @discardableResult
    func addShifts(_ newShifts: [Shift]) -> Int {
        let fresh = newShifts.filter { new in
            !shifts.contains { $0.workplace.id == new.workplace.id && $0.start == new.start && $0.end == new.end }
        }
        for shift in fresh {
            context?.insert(ShiftRecord(from: shift, workplace: workplaceRecord(shift.workplace.id)))
        }
        shifts.append(contentsOf: fresh)
        shifts.sort { $0.start < $1.start }
        persist()
        return fresh.count
    }
    
    func updateShift(_ shift: Shift) {
        guard let index = shifts.firstIndex(where: { $0.id == shift.id }) else { return }
        shifts[index] = shift
        shifts.sort { $0.start < $1.start }
        
        if let record = shiftRecord(shift.id) {
            record.start = shift.start
            record.end = shift.end
            record.workplace = workplaceRecord(shift.workplace.id)
        }
        persist()
    }
    
    func deleteShift(_ id: UUID) {
        shifts.removeAll { $0.id == id }
        if let record = shiftRecord(id) {
            context?.delete(record)
        }
        persist()
    }
    
    /// 같은 직장·같은 시간의 다른 근무가 이미 있는지
    func isDuplicate(_ shift: Shift) -> Bool {
        shifts.contains {
            $0.id != shift.id && $0.workplace.id == shift.workplace.id
            && $0.start == shift.start && $0.end == shift.end
        }
    }
    
    /// 시간이 겹치는 다른 근무들 (직장 상관없이)
    func overlappingShifts(start: Date, end: Date, excluding id: UUID?) -> [Shift] {
        shifts.filter { $0.id != id && $0.start < end && start < $0.end }
    }
    
    // MARK: - 개발용 (TODO: 출시 전 Settings의 Developer 구역과 함께 삭제)
    
    /// 비어 있을 때만 테스트 데이터 넣기
    func loadSampleData() {
        guard workplaces.isEmpty, shifts.isEmpty else { return }
        insert(SampleData.cafe)
        insert(SampleData.restaurant)
        addShifts(SampleData.shifts)
    }
    
    /// 모든 데이터 지우기
    func eraseAllData() {
        if let context {
            try? context.delete(model: ShiftRecord.self)
            try? context.delete(model: WorkplaceRecord.self)
            persist()
        }
        shifts = []
        workplaces = []
        alarmSettings = AlarmSettings()
    }
    
    // MARK: - 저장소 내부
    
    private func workplaceRecord(_ id: UUID) -> WorkplaceRecord? {
        let descriptor = FetchDescriptor<WorkplaceRecord>(predicate: #Predicate { $0.id == id })
        return try? context?.fetch(descriptor).first
    }
    
    private func shiftRecord(_ id: UUID) -> ShiftRecord? {
        let descriptor = FetchDescriptor<ShiftRecord>(predicate: #Predicate { $0.id == id })
        return try? context?.fetch(descriptor).first
    }
    
    /// 바뀐 내용을 기기에 저장 (프리뷰에서는 아무것도 안 함)
    private func persist() {
        guard let context else { return }
        do {
            try context.save()
        } catch {
            print("⚠️ Could not save: \(error)")
        }
        scheduleReminderSync()
    }
    
    // MARK: - 알람 설정 (UserDefaults)
    
    private static let alarmSettingsKey = "alarmSettings"
    
    private static func loadAlarmSettings() -> AlarmSettings {
        guard let data = UserDefaults.standard.data(forKey: alarmSettingsKey),
              let settings = try? JSONDecoder().decode(AlarmSettings.self, from: data)
        else { return AlarmSettings() }
        return settings
    }
    
    private func saveAlarmSettings() {
        guard container != nil else { return }   // 프리뷰는 저장 안 함
        if let data = try? JSONEncoder().encode(alarmSettings) {
            UserDefaults.standard.set(data, forKey: Self.alarmSettingsKey)
        }
        scheduleReminderSync()
    }
    
    // MARK: - 리마인더 알림
    
    /// 리마인더 알림을 지금 근무·설정에 맞게 다시 예약 (화면에서 직접 불러도 됨)
    func refreshReminders() {
        scheduleReminderSync()
    }
    
    /// 앞의 작업이 끝난 뒤 차례로 실행 → 여러 번 바뀌어도 마지막 상태로 맞춰짐
    private func scheduleReminderSync() {
        guard container != nil else { return }   // 프리뷰는 알림 예약 안 함
        let previous = syncTask
        syncTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await ReminderScheduler.sync(shifts: self.shifts, settings: self.alarmSettings)
            await WakeAlarmSync.sync(shifts: self.shifts, settings: self.alarmSettings)
        }
    }
}
