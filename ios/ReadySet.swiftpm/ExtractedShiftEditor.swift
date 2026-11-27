import SwiftUI

/// 수정 창에서 다룰 대상: 기존 근무 수정 또는 새 근무 추가
enum ShiftEditorTarget: Identifiable {
    case existing(ExtractedShift)
    case new(ExtractedShift)
    
    var id: UUID {
        switch self {
        case .existing(let shift), .new(let shift): shift.id
        }
    }
}

/// 근무 1건 수정/추가 창
struct ExtractedShiftEditor: View {
    let shift: ExtractedShift
    let isNew: Bool
    let onSave: (ExtractedShift) -> Void
    let onDelete: (() -> Void)?          // nil이면 Delete 버튼 숨김
    
    // 창 안에서만 쓰는 임시 값 (Save를 눌러야 목록에 반영)
    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        shift: ExtractedShift,
        isNew: Bool,
        onSave: @escaping (ExtractedShift) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.shift = shift
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _day = State(initialValue: shift.start)
        _startTime = State(initialValue: shift.start)
        // 종료 시간이 없으면(마감) 일단 시작 8시간 뒤로 채워 둠
        _endTime = State(initialValue: shift.end ?? shift.start.addingTimeInterval(8 * 60 * 60))
    }
    
    // MARK: 계산 값
    private var startDate: Date {
        CalendarMath.combine(day: day, time: startTime)
    }
    
    private var endDate: Date {
        CalendarMath.shiftEnd(start: startDate, endTime: endTime)
    }
    
    private var isOvernight: Bool {
        !Calendar.current.isDate(endDate, inSameDayAs: startDate)
    }
    
    private var shiftLength: String {
        TextFormat.duration(from: startDate, to: endDate)
    }
    
    /// 시작과 종료가 같은 시계 시각(시·분)이면 저장 불가
    private var isValid: Bool {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: startTime)
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        return start.hour != end.hour || start.minute != end.minute
    }
    
    // MARK: 화면
    var body: some View {
        NavigationStack {
            Form {
                // 근무표 원문 (인식된 근무일 때만)
                if !shift.rawText.isEmpty {
                    Section {
                        LabeledContent("On schedule", value: shift.rawText)
                    } footer: {
                        if shift.end == nil {
                            Text("The schedule says this shift ends at close. Please set the end time.")
                        } else if shift.isTimeAssumed {
                            Text("AM or PM wasn't shown, so we guessed. Please check the times.")
                        }
                    }
                }
                
                Section {
                    DatePicker("Date", selection: $day, displayedComponents: .date)
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                } footer: {
                    if !isValid {
                        Text("The end time can't be the same as the start time.")
                    } else if isOvernight {
                        Text("\(shiftLength) shift · Ends the next day, \(endDate.shortDayText).")
                    } else {
                        Text("\(shiftLength) shift")
                    }
                }
                
                if let onDelete {
                    Section {
                        Button("Delete Shift", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Shift" : "Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = shift              // 원본을 복사해서
                        updated.start = startDate        // 바뀐 값만 덮어쓰기
                        updated.end = endDate
                        updated.isTimeAssumed = false    // 사용자가 확인함
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Edit — guessed time") {
    ExtractedShiftEditor(
        shift: SampleExtraction.cafeA.shifts[0],
        isNew: false,
        onSave: { _ in },
        onDelete: { }
    )
}

#Preview("Edit — overnight") {
    ExtractedShiftEditor(
        shift: SampleExtraction.restaurantB.shifts[1],
        isNew: false,
        onSave: { _ in },
        onDelete: { }
    )
}
