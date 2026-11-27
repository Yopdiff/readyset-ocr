import SwiftUI

// MARK: - Calendar / List 전환 버튼
struct ModeToggle: View {
    @Binding var selection: ShiftsMode
    
    var body: some View {
        HStack(spacing: 8) {
            segment("Calendar", mode: .calendar)
            segment("List", mode: .list)
        }
    }
    
    private func segment(_ title: String, mode: ShiftsMode) -> some View {
        let isSelected = selection == mode
        return Button {
            selection = mode
        } label: {
            Text(title)
                .font(AppFont.montserrat(12, .bold, relativeTo: .footnote))
                .foregroundStyle(isSelected ? AppColor.background : AppColor.primary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    isSelected ? AppColor.primary : AppColor.muted.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Calendar 모드
struct CalendarModeView: View {
    let shifts: [Shift]
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date = .now
    
    var body: some View {
        let dayShifts = ShiftSchedule.shifts(in: shifts, on: selectedDate)
        
        VStack(spacing: 16) {
            MonthCalendarView(
                month: displayedMonth,
                shifts: shifts,
                selectedDate: $selectedDate,
                onPrevious: { displayedMonth = CalendarMath.month(byAdding: -1, to: displayedMonth) },
                onNext: { displayedMonth = CalendarMath.month(byAdding: 1, to: displayedMonth) }
            )
            
            SelectedDayCard(date: selectedDate, shifts: dayShifts)
            
            AddShiftButton(date: selectedDate)
        }
        // 선택된 날짜가 바뀌면(예: Home에서 이동해 오면) 그 달을 보여줌
        .task(id: selectedDate) {
            displayedMonth = CalendarMath.startOfMonth(for: selectedDate)
        }
    }
}

// MARK: - 월간 달력
struct MonthCalendarView: View {
    let month: Date
    let shifts: [Shift]
    @Binding var selectedDate: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        let calendar = Calendar.current
        
        VStack(spacing: 8) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous month")
                
                Spacer()
                Text(month.monthYearText)
                    .font(AppFont.montserrat(17, .semibold, relativeTo: .headline))
                Spacer()
                
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next month")
            }
            .buttonStyle(.plain)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(CalendarMath.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                        .padding(.bottom, 4)
                }
                
                ForEach(CalendarMath.monthGrid(for: month)) { item in
                    if let date = item.date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            workplaces: ShiftSchedule.workplaces(in: shifts, on: date),
                            onTap: { selectedDate = date }
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - 달력의 하루 칸
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let workplaces: [Workplace]     // 그날 근무하는 직장들
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(AppFont.montserrat(14, isSelected ? .bold : .regular, relativeTo: .body))
                    .foregroundStyle(isSelected ? AppColor.background : AppColor.primary)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? AppColor.primary : Color.clear, in: Circle())
                    .overlay {
                        if isToday {   // 오늘: 네모 테두리
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColor.primary, lineWidth: 1)
                        }
                    }
                
                // 직장 색 점 (최대 3개)
                HStack(spacing: 2) {
                    ForEach(workplaces.prefix(3)) { workplace in
                        Circle()
                            .fill(workplace.color.color)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var accessibilityText: String {
        var text = date.longDayText
        if isToday { text += ", today" }
        if !workplaces.isEmpty {
            text += ", shifts at " + workplaces.map(\.name).joined(separator: ", ")
        }
        return text
    }
}

// MARK: - 선택한 날짜 카드
struct SelectedDayCard: View {
    let date: Date
    let shifts: [Shift]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.longDayText)
                    .font(AppFont.montserrat(17, .bold, relativeTo: .headline))
                Spacer()
                if !shifts.isEmpty {
                    Text(TextFormat.shiftCount(shifts.count))
                        .font(AppFont.montserrat(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                }
            }
            
            if shifts.isEmpty {
                Text("Day off 🌲")
                    .font(AppFont.montserrat(14, relativeTo: .body))
            } else {
                ForEach(shifts) { shift in
                    ShiftDetailRow(shift: shift)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - 근무 한 건 (Calendar와 List에서 공용)
struct ShiftDetailRow: View {
    let shift: Shift
    @EnvironmentObject private var store: ShiftStore
    
    var body: some View {
        let now = Date.now
        // 실제로 예약되는 알람과 같은 규칙
        let wakeUp = WakeAlarmPlanner.wakeUpTime(for: shift, among: store.shifts, settings: store.alarmSettings, now: now)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WorkplaceLabel(workplace: shift.workplace, font: AppFont.montserrat(16, .semibold, relativeTo: .headline))
                Spacer()
                NavigationLink(value: ShiftsRoute.editShift(shift)) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit shift")
            }
            
            Label(shift.timeRangeText, systemImage: "clock")
            if let wakeUp {
                Label("Wake-up alarm: \(wakeUp.shortTimeText)", systemImage: "alarm")
            } else if shift.start > now {
                // 앞 근무 중이라 알람을 건너뛴 경우 (지난 근무는 아무것도 안 보여줌)
                Label("No wake-up alarm", systemImage: "alarm")
            }
        }
        .font(AppFont.montserrat(13, relativeTo: .subheadline))
    }
}

// MARK: - 점선 "+ Add a shift" 버튼
struct AddShiftButton: View {
    let date: Date
    
    var body: some View {
        NavigationLink(value: ShiftsRoute.addShift(date)) {
            Text("+ Add a shift")
                .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColor.muted, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - List 모드 (주간 목록)
struct ListModeView: View {
    let shifts: [Shift]
    @Binding var selectedDate: Date
    
    var body: some View {
        let week = CalendarMath.week(containing: selectedDate)
        let weekShifts = ShiftSchedule.shifts(in: shifts, during: week)
        let days = ShiftSchedule.groupedByDay(weekShifts)
        
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { moveWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous week")
                
                Spacer()
                VStack(spacing: 2) {
                    Text(TextFormat.weekRange(week))
                        .font(AppFont.montserrat(17, .semibold, relativeTo: .headline))
                    Text(TextFormat.shiftCount(weekShifts.count))
                        .font(AppFont.montserrat(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                }
                Spacer()
                
                Button { moveWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next week")
            }
            .buttonStyle(.plain)
            
            if days.isEmpty {
                Text("No shifts this week")
                    .font(AppFont.montserrat(14, relativeTo: .body))
                    .foregroundStyle(AppColor.primary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                ForEach(days) { day in
                    Text(day.date.shortDayText)
                        .font(AppFont.montserrat(14, .medium, relativeTo: .subheadline))
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(day.shifts) { shift in
                            ShiftDetailRow(shift: shift)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
            }
        }
    }
    
    private func moveWeek(by weeks: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) {
            selectedDate = newDate
        }
    }
}
