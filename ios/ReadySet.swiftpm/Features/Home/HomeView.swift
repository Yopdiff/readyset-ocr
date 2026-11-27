import SwiftUI

struct HomeView: View {
    let shifts: [Shift]
    var onOpenCalendar: (Date) -> Void = { _ in }   // NEXT SHIFT › 눌렀을 때
    var onOpenList: () -> Void = { }                // See all › 눌렀을 때
    
    @State private var isShowingAddSchedule = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // 1분마다 다시 그려요: 시작한 근무가 NEXT SHIFT에 계속 남지 않게
                TimelineView(.everyMinute) { context in
                    content(now: context.date)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingAddSchedule) {
                AddScheduleView(onFinish: { isShowingAddSchedule = false })
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let futureShifts = ShiftSchedule.futureShifts(in: shifts, after: now)
        let nextShift = futureShifts.first
        let upcoming = Array(futureShifts.dropFirst().prefix(2))   // 다음 근무 이후 2개

        VStack(spacing: 0) {
            HomeHeader(
                date: now,
                isDayOff: !ShiftSchedule.hasShift(in: shifts, on: now),
                onAddTapped: { isShowingAddSchedule = true }
            )
            .padding(.top, 24)
            
            if let nextShift {
                // 근무가 있을 때
                NextShiftCard(shift: nextShift, now: now) {
                    onOpenCalendar(nextShift.start)
                }
                .padding(.top, 24)
                
                if !upcoming.isEmpty {
                    UpcomingShiftsSection(shifts: upcoming, onSeeAll: onOpenList)
                        .padding(.top, 28)
                }
                
                AddScheduleButton { isShowingAddSchedule = true }
                    .padding(.top, 20)
            } else {
                // 근무가 없을 때
                EmptyShiftsView()
                    .padding(.top, 64)
                
                PrimaryButton(title: "Add your first schedule", systemImage: "plus") {
                    isShowingAddSchedule = true
                }
                .padding(.top, 40)
            }
        }
    }
}

#Preview("With shifts") {
    HomeView(shifts: SampleData.shifts)
         .environmentObject(ShiftStore.sample)
}

#Preview("Empty") {
    HomeView(shifts: [])
         .environmentObject(ShiftStore.sample)
}
