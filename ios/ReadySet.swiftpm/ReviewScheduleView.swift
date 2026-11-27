import SwiftUI

struct ReviewScheduleView: View {
    let image: UIImage
    let schedule: RecognizedSchedule
    let onFinish: () -> Void
    
    @EnvironmentObject private var store: ShiftStore
    @State private var result: ExtractionResult
    @State private var selectedWorkplaceID: UUID?
    
    // 이름 선택
    @State private var confirmedLabel: String?
    @State private var requiresNameChoice = false
    @State private var isPickingName = false
    @State private var isTypingName = false
    @State private var typedName = ""
    
    // 고친 내용 보호
    @State private var hasEdits = false               // 근무나 주를 손으로 고쳤는지
    @State private var pendingChange: PendingChange?  // 확인창에서 기다리는 변경
    
    @State private var isShowingFullImage = false
    @State private var editorTarget: ShiftEditorTarget?
    @State private var isShowingNewWorkplace = false
    @State private var isShowingWeekPicker = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(image: UIImage, schedule: RecognizedSchedule, onFinish: @escaping () -> Void = { }) {
        self.image = image
        self.schedule = schedule
        self.onFinish = onFinish
        _result = State(initialValue: schedule.extract([]))
    }
    
    private struct RecognitionKey: Hashable {
        let workplaceID: UUID?
        let label: String?
    }
    
    /// 인식을 다시 실행하게 만드는 변경
    private enum PendingChange {
        case workplace(UUID?)
        case name(String)
    }
    
    // MARK: 계산 값
    
    private var selectedWorkplace: Workplace? {
        store.workplaces.first { $0.id == selectedWorkplaceID }
    }
    
    /// 직장 드롭다운용: 바꾸기 전에 확인을 거침
    private var workplaceSelection: Binding<UUID?> {
        Binding(
            get: { selectedWorkplaceID },
            set: { newID in requestChange(.workplace(newID)) }
        )
    }
    
    private var scheduleRange: DateInterval? {
        let starts = result.shifts.map(\.start)
        guard let first = starts.min() ?? result.weekStart else { return nil }
        let last = starts.max() ?? first
        return DateInterval(
            start: CalendarMath.week(containing: first).start,
            end: CalendarMath.week(containing: last).end
        )
    }
    
    /// 진짜 이름 (OCR 표기가 직장의 Employee name과 다르지만 비슷할 때만). 예: "Jiwoa" → "Jiwoo"
    private var preferredName: String? {
        guard let label = result.matchedName,
              let name = selectedWorkplace?.nameOnSchedule, !name.isEmpty,
              label.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame,
              NameMatching.score(label: label, against: [name]) >= NameMatching.threshold
        else { return nil }
        return name
    }
    
    private var saveBlocker: String? {
        if selectedWorkplace == nil { return "Choose a workplace to continue." }
        if requiresNameChoice { return "Tap your name on the schedule to continue." }
        if result.shifts.isEmpty { return "Add at least one shift." }
        if result.shifts.contains(where: { $0.end == nil }) {
            return "Set an end time for shifts marked “Close”."
        }
        return nil
    }
    
    // MARK: 화면
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review Schedule")
                    .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    .padding(.top, 8)
                
                SchedulePreview(image: image)
                    .padding(.top, 20)
                
                HStack {
                    Button {
                        isShowingFullImage = true
                    } label: {
                        Label("View full image", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Label("Change photo", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .font(AppFont.montserrat(12, .medium, relativeTo: .footnote))
                .buttonStyle(.plain)
                .padding(.top, 10)
                
                Label("Suggested details", systemImage: "sparkles")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                    .padding(.top, 28)
                
                // 1. Workplace
                FieldLabel("WORKPLACE")
                    .padding(.top, 12)
                WorkplacePicker(
                    workplaces: store.workplaces,
                    selectedID: workplaceSelection,
                    onNewWorkplace: {
                        withAnimation { isShowingNewWorkplace = true }
                    }
                )
                .padding(.top, 8)
                
                // 2. We'll look for
                FieldLabel("We'll look for")
                    .padding(.top, 24)
                NameMatchSection(
                    result: result,
                    requiresChoice: requiresNameChoice,
                    preferredName: preferredName,
                    isPicking: $isPickingName,
                    onPick: { label in requestChange(.name(label)) },
                    onTypeName: {
                        typedName = ""
                        isTypingName = true
                    }
                )
                .padding(.top, 8)
                
                // 3. Schedule Week
                if let range = scheduleRange {
                    HStack(alignment: .firstTextBaseline) {
                        FieldLabel("Schedule Week")
                        Spacer()
                        Label("Please confirm the dates.", systemImage: "info.circle")
                            .font(AppFont.montserrat(11, relativeTo: .caption))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    .padding(.top, 24)
                    
                    ScheduleWeekField(range: range) {
                        isShowingWeekPicker = true
                    }
                    .padding(.top, 8)
                }
                
                // 4. Extracted shifts (이름을 고르기 전에는 숨김)
                if requiresNameChoice {
                    Text("Extracted shifts")
                        .font(AppFont.montserrat(20, .bold, relativeTo: .title3))
                        .padding(.top, 28)
                    ReviewNote(text: "Choose your name above to see your shifts.")
                        .padding(.top, 8)
                } else {
                    ExtractedShiftsSection(
                        shifts: result.shifts,
                        onEdit: { shift in editorTarget = .existing(shift) },
                        onAdd: { editorTarget = .new(makeNewShift()) }
                    )
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let saveBlocker {
                    Text(saveBlocker)
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                }
                PrimaryButton(title: "Add my shifts", minHeight: 52) {
                    saveShifts()
                }
                .disabled(saveBlocker != nil)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(AppColor.background)
        }
        .foregroundStyle(AppColor.primary)
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isShowingNewWorkplace)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if isShowingNewWorkplace {
                WorkplaceDialog(
                    title: "Add New Workplace",
                    saveTitle: "Save Workplace",
                    initialNameOnSchedule: confirmedLabel ?? result.matchedName ?? "",
                    onSave: { name, nameOnSchedule in
                        let workplace = store.addWorkplace(name: name, nameOnSchedule: nameOnSchedule)
                        withAnimation { isShowingNewWorkplace = false }
                        requestChange(.workplace(workplace.id))
                    },
                    onClose: {
                        withAnimation { isShowingNewWorkplace = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            if selectedWorkplaceID == nil, store.workplaces.count == 1 {
                selectedWorkplaceID = store.workplaces[0].id
            }
        }
        .task(id: RecognitionKey(workplaceID: selectedWorkplaceID, label: confirmedLabel)) {
            runRecognition()
        }
        // 고친 내용이 사라지기 전 확인
        .alert(
            "Discard your changes?",
            isPresented: Binding(
                get: { pendingChange != nil },
                set: { if !$0 { pendingChange = nil } }
            ),
            presenting: pendingChange
        ) { change in
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) { apply(change) }
        } message: { _ in
            Text("Changing the workplace or name will find your shifts again. Changes you've made to the shifts or schedule week will be lost.")
        }
        .alert("Your name on the schedule", isPresented: $isTypingName) {
            TextField("e.g. Park, J.", text: $typedName)
            Button("Search") {
                let name = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { requestChange(.name(name)) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Type your name the way it's written on this schedule.")
        }
        .fullScreenCover(isPresented: $isShowingFullImage) {
            FullImageView(image: image)
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .existing(let shift):
                ExtractedShiftEditor(
                    shift: shift,
                    isNew: false,
                    onSave: { updated in save(updated) },
                    onDelete: { delete(shift) }
                )
            case .new(let shift):
                ExtractedShiftEditor(
                    shift: shift,
                    isNew: true,
                    onSave: { added in save(added) }
                )
            }
        }
        .sheet(isPresented: $isShowingWeekPicker) {
            ScheduleWeekSheet(weekStart: scheduleRange?.start ?? .now) { date in
                moveSchedule(toWeekContaining: date)
            }
        }
    }
    
    // MARK: - 직장·이름 변경 (고친 내용이 있으면 먼저 확인)
    
    private func requestChange(_ change: PendingChange) {
        if hasEdits {
            pendingChange = change      // 확인창 띄우기
        } else {
            apply(change)
        }
    }
    
    private func apply(_ change: PendingChange) {
        switch change {
        case .workplace(let id):
            selectedWorkplaceID = id
        case .name(let label):
            confirmedLabel = label
            isPickingName = false
        }
    }
    
    // MARK: - 이름으로 찾기
    
    private func runRecognition() {
        hasEdits = false   // 결과를 새로 만들면 고친 내용은 초기화됨
        
        // 1) 사용자가 직접 고른 이름
        if let confirmedLabel {
            result = schedule.extract([confirmedLabel])
            requiresNameChoice = false
            return
        }
        
        // 2) 직장을 안 골랐으면: 근무표 속 이름이 어느 직장에서 기억한 이름과 맞는지 확인 → 직장까지 자동 선택
        if selectedWorkplace == nil {
            for workplace in store.workplaces where !workplace.aliases.isEmpty {
                let found = schedule.extract(workplace.aliases)
                if found.matchedName != nil, !found.isNameAmbiguous {
                    selectedWorkplaceID = workplace.id
                    result = found
                    requiresNameChoice = false
                    return
                }
            }
        }
        
        // 3) 고른 직장에서 기억한 이름으로 자동 매칭
        if let aliases = selectedWorkplace?.aliases, !aliases.isEmpty {
            let found = schedule.extract(aliases)
            if found.matchedName != nil, !found.isNameAmbiguous {
                result = found
                requiresNameChoice = false
                return
            }
        }
        
        // 4) 처음 보는 근무표: 기본 이름으로 추천만 하고, 사용자가 직접 고르게 함
        result = schedule.extract(store.suggestionNames(for: selectedWorkplace))
        requiresNameChoice = !result.nameCandidates.isEmpty
    }
    
    // MARK: - 목록 변경
    
    private func save(_ shift: ExtractedShift) {
        if let index = result.shifts.firstIndex(where: { $0.id == shift.id }) {
            result.shifts[index] = shift
        } else {
            result.shifts.append(shift)
        }
        result.shifts.sort { $0.start < $1.start }
        hasEdits = true
    }
    
    private func delete(_ shift: ExtractedShift) {
        result.shifts.removeAll { $0.id == shift.id }
        hasEdits = true
    }
    
    private func makeNewShift() -> ExtractedShift {
        let calendar = Calendar.current
        let baseDay: Date
        if let last = result.shifts.last {
            baseDay = calendar.date(byAdding: .day, value: 1, to: last.start) ?? last.start
        } else {
            baseDay = result.weekStart ?? .now
        }
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDay) ?? baseDay
        return ExtractedShift(start: start, end: start.addingTimeInterval(8 * 60 * 60))
    }
    
    private func moveSchedule(toWeekContaining date: Date) {
        guard let range = scheduleRange else { return }
        let calendar = Calendar.current
        let newWeekStart = CalendarMath.week(containing: date).start
        let dayOffset = calendar.dateComponents([.day], from: range.start, to: newWeekStart).day ?? 0
        guard dayOffset != 0 else { return }
        
        for index in result.shifts.indices {
            let shift = result.shifts[index]
            result.shifts[index].start = calendar.date(byAdding: .day, value: dayOffset, to: shift.start) ?? shift.start
            if let end = shift.end {
                result.shifts[index].end = calendar.date(byAdding: .day, value: dayOffset, to: end) ?? end
            }
        }
        if let weekStart = result.weekStart {
            result.weekStart = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
        result.datesAssumed = false
        hasEdits = true
    }
    
    // MARK: - 저장
    
    private func saveShifts() {
        guard let chosen = selectedWorkplace else { return }
        
        if let label = confirmedLabel ?? result.matchedName {
            store.addAlias(label, to: chosen.id)
        }
        let workplace = selectedWorkplace ?? chosen
        
        let newShifts = result.shifts.compactMap { extracted -> Shift? in
            guard let end = extracted.end else { return nil }
            return Shift(workplace: workplace, start: extracted.start, end: end)
        }
        store.addShifts(newShifts)
        onFinish()
    }
}

#Preview("Café A — pick a name") {
    NavigationStack {
        ReviewScheduleView(image: UIImage(systemName: "tablecells")!, schedule: SampleSchedules.cafeA)
    }
    .environmentObject(ShiftStore.sample)
}

#Preview("Restaurant B — overnight") {
    NavigationStack {
        ReviewScheduleView(image: UIImage(systemName: "tablecells")!, schedule: SampleSchedules.restaurantB)
    }
    .environmentObject(ShiftStore.sample)
}
