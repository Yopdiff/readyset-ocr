import SwiftUI

/// 근무 추가·수정 화면 (My Shifts, Enter shifts manually에서 사용)
struct ShiftFormView: View {
    enum Mode {
        case add(Date)      // 이 날짜로 새 근무
        case edit(Shift)    // 이 근무 수정
    }
    
    let mode: Mode
    var onFinish: (() -> Void)? = nil   // 있으면 저장 후 이 동작 (없으면 이전 화면으로)
    
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var workplaceID: UUID?
    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    
    @State private var isShowingNewWorkplace = false
    @State private var isConfirmingDelete = false
    @State private var isShowingDuplicateAlert = false
    
    init(mode: Mode, onFinish: (() -> Void)? = nil) {
        self.mode = mode
        self.onFinish = onFinish
        
        switch mode {
        case .add(let date):
            let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            _workplaceID = State(initialValue: nil)
            _day = State(initialValue: start)
            _startTime = State(initialValue: start)
            _endTime = State(initialValue: start.addingTimeInterval(8 * 60 * 60))
        case .edit(let shift):
            _workplaceID = State(initialValue: shift.workplace.id)
            _day = State(initialValue: shift.start)
            _startTime = State(initialValue: shift.start)
            _endTime = State(initialValue: shift.end)
        }
    }
    
    // MARK: 계산 값
    
    private var originalShift: Shift? {
        if case .edit(let shift) = mode { return shift }
        return nil
    }
    
    private var isEditing: Bool { originalShift != nil }
    
    /// 선택지: 저장된 직장 + (수정 중인 근무의 직장이 삭제됐다면 그 직장도)
    private var workplaceOptions: [Workplace] {
        var options = store.workplaces
        if let original = originalShift?.workplace,
           !options.contains(where: { $0.id == original.id }) {
            options.append(original)
        }
        return options
    }
    
    private var selectedWorkplace: Workplace? {
        workplaceOptions.first { $0.id == workplaceID }
    }
    
    private var startDate: Date {
        CalendarMath.combine(day: day, time: startTime)
    }
    
    private var endDate: Date {
        CalendarMath.shiftEnd(start: startDate, endTime: endTime)
    }
    
    private var isOvernight: Bool {
        !Calendar.current.isDate(endDate, inSameDayAs: startDate)
    }
    
    /// 시작과 종료가 같은 시계 시각이면 안 됨
    private var isTimeValid: Bool {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: startTime)
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        return start.hour != end.hour || start.minute != end.minute
    }
    
    private var canSave: Bool {
        selectedWorkplace != nil && isTimeValid
    }
    
    private var wakeUpTime: Date {
        startDate.addingTimeInterval(-Double(store.alarmSettings.wakeUpMinutesBefore) * 60)
    }
    
    private var overlapping: Shift? {
        guard isTimeValid else { return nil }
        return store.overlappingShifts(start: startDate, end: endDate, excluding: originalShift?.id).first
    }
    
    // MARK: 화면
    
    var body: some View {
        Form {
            Section("Workplace") {
                Picker("Workplace", selection: $workplaceID) {
                    if workplaceID == nil {
                        Text("Choose").tag(UUID?.none)
                    }
                    ForEach(workplaceOptions) { workplace in
                        Text(workplace.name).tag(Optional(workplace.id))
                    }
                }
                Button("+ New workplace") {
                    withAnimation { isShowingNewWorkplace = true }
                }
            }
            
            Section {
                DatePicker("Date", selection: $day, displayedComponents: .date)
                DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
            } footer: {
                if !isTimeValid {
                    Text("The end time can't be the same as the start time.")
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isOvernight
                             ? "\(TextFormat.duration(from: startDate, to: endDate)) shift · Ends the next day, \(endDate.shortDayText)."
                             : "\(TextFormat.duration(from: startDate, to: endDate)) shift")
                        Text("Wake-up alarm: \(wakeUpTime.relativeDayTimeText(now: startDate))")
                    }
                }
            }
            
            if let overlapping {
                Section {
                    Label(
                        "Overlaps with \(overlapping.workplace.name), \(overlapping.start.shortDayText) \(overlapping.timeRangeText).",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                }
            }
            
            if isEditing {
                Section {
                    Button("Delete Shift", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Shift" : "Add Shift")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isShowingNewWorkplace)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            if workplaceID == nil, store.workplaces.count == 1 {
                workplaceID = store.workplaces[0].id
            }
        }
        .overlay {
            if isShowingNewWorkplace {
                WorkplaceDialog(
                    title: "Add New Workplace",
                    saveTitle: "Save Workplace",
                    onSave: { name, nameOnSchedule in
                        let workplace = store.addWorkplace(name: name, nameOnSchedule: nameOnSchedule)
                        workplaceID = workplace.id
                        withAnimation { isShowingNewWorkplace = false }
                    },
                    onClose: {
                        withAnimation { isShowingNewWorkplace = false }
                    }
                )
                .transition(.opacity)
            }
        }
        .alert("Delete this shift?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let original = originalShift {
                    store.deleteShift(original.id)
                    // TODO (Phase 4): 이 근무의 알람·리마인더 취소
                }
                finish()
            }
        } message: {
            Text("Its wake-up alarm and reminders will be removed too.")
        }
        .alert("This shift already exists", isPresented: $isShowingDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have a shift at this workplace with the same start and end time.")
        }
    }
    
    // MARK: - 저장
    
    private func save() {
        guard let workplace = selectedWorkplace else { return }
        
        switch mode {
        case .add:
            let shift = Shift(workplace: workplace, start: startDate, end: endDate)
            if store.addShifts([shift]) == 0 {       // 0개 추가 = 이미 있는 근무
                isShowingDuplicateAlert = true
                return
            }
        case .edit(let original):
            var updated = original
            updated.workplace = workplace
            updated.start = startDate
            updated.end = endDate
            if store.isDuplicate(updated) {
                isShowingDuplicateAlert = true
                return
            }
            store.updateShift(updated)
        }
        // TODO (Phase 4): 이 근무의 알람·리마인더 예약/다시 예약
        finish()
    }
    
    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

#Preview("Add") {
    NavigationStack {
        ShiftFormView(mode: .add(.now))
    }
    .environmentObject(ShiftStore.sample)
}

#Preview("Edit") {
    NavigationStack {
        ShiftFormView(mode: .edit(SampleData.shifts[0]))
    }
    .environmentObject(ShiftStore.sample)
}
