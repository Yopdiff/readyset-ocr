import SwiftUI

// MARK: - 상단 헤더 (기존 코드에서 이동)
struct HomeHeader: View {
    let date: Date
    let isDayOff: Bool
    let onAddTapped: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Today")
                        .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    Text(isDayOff ? "🌲" : "💼")
                        .font(.system(size: 26))
                        .accessibilityLabel(isDayOff ? "Day off" : "Work day")
                }
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(AppFont.montserrat(15, relativeTo: .subheadline))
            }
            .foregroundStyle(AppColor.primary)
            
            Spacer()
            
            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.background)
                    .frame(width: 36, height: 36)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Add schedule")
        }
    }
}

// MARK: - 근무가 없을 때 안내 (기존 코드에서 이동)
struct EmptyShiftsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .frame(width: 72, height: 72)
                .background(AppColor.muted, in: Circle())
            
            Text("No shifts yet")
                .font(AppFont.montserrat(22, .bold, relativeTo: .title2))
                .padding(.top, 20)
            
            Text("Add your first work schedule to see upcoming shifts and set up your alarms.")
                .font(AppFont.montserrat(12, relativeTo: .footnote))
                .foregroundStyle(AppColor.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 24)
        }
        .foregroundStyle(AppColor.primary)
    }
}

// MARK: - NEXT SHIFT 카드
struct NextShiftCard: View {
    let shift: Shift
    let now: Date
    let onOpenCalendar: () -> Void
    
    @EnvironmentObject private var store: ShiftStore
    
    var body: some View {
        let settings = store.alarmSettings
        let wakeUp = AlarmCalculator.wakeUpTime(for: shift, settings: settings)
        let reminder = AlarmCalculator.nextReminder(for: shift, settings: settings, after: now)
        
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpenCalendar) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT SHIFT")
                            .font(AppFont.montserrat(11, .medium, relativeTo: .caption))
                            .tracking(0.5)
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                        Text(shift.start.relativeDayTimeText(now: now))
                            .font(AppFont.montserrat(20, .bold, relativeTo: .title3))
                            .padding(.top, 4)
                        WorkplaceLabel(workplace: shift.workplace, font: AppFont.montserrat(15, .medium, relativeTo: .body))
                        Text(shift.timeRangeText)
                            .font(AppFont.montserrat(13, relativeTo: .subheadline))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the calendar")
            
            Divider()
                .padding(.vertical, 16)
            
            AlarmInfoRow(
                systemImage: "alarm",
                title: wakeUp.relativeDayTimeText(now: now),
                detail: "Wake-up alarm · \(TextFormat.longDuration(minutes: settings.wakeUpMinutesBefore)) before"
            )
            
            if let reminder {
                AlarmInfoRow(
                    systemImage: "bell",
                    detail: "Shift reminder · \(reminder.relativeDayTimeText(now: now))"
                )
                .padding(.top, 14)
            }
        }
        .foregroundStyle(AppColor.primary)
        .padding(20)
        .cardStyle()
    }
}

// MARK: - 알람/리마인더 한 줄
struct AlarmInfoRow: View {
    let systemImage: String
    var title: String? = nil
    let detail: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(AppFont.montserrat(15, .bold, relativeTo: .body))
                }
                Text(detail)
                    .font(AppFont.montserrat(11, relativeTo: .caption))
            }
        }
    }
}

// MARK: - Upcoming shifts 섹션
struct UpcomingShiftsSection: View {
    let shifts: [Shift]
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming shifts")
                    .font(AppFont.montserrat(17, .bold, relativeTo: .headline))
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 2) {
                        Text("See all")
                            .font(AppFont.montserrat(12, .medium, relativeTo: .footnote))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 0) {
                ForEach(shifts) { shift in
                    UpcomingShiftRow(shift: shift)
                    if shift.id != shifts.last?.id {
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
            .cardStyle()
        }
        .foregroundStyle(AppColor.primary)
    }
}

struct UpcomingShiftRow: View {
    let shift: Shift
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.start.shortDayText)
                    .font(AppFont.montserrat(14, .bold, relativeTo: .subheadline))
                WorkplaceLabel(workplace: shift.workplace, font: AppFont.montserrat(12, relativeTo: .caption))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
            }
            Spacer()
            Text(shift.timeRangeText)
                .font(AppFont.montserrat(13, relativeTo: .subheadline))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - 근무 있을 때의 Add Schedule 버튼
struct AddScheduleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                Text("Add Schedule")
                    .font(AppFont.montserrat(17, .semibold, relativeTo: .headline))
                    .padding(.top, 4)
                Text("Upload your work schedule")
                    .font(AppFont.montserrat(11, relativeTo: .caption))
                    .opacity(0.6)
            }
            .foregroundStyle(AppColor.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
