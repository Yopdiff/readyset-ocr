import SwiftUI

/// My Shifts 탭에서 이동할 수 있는 화면들
enum ShiftsRoute: Hashable {
    case addShift(Date)
    case editShift(Shift)
}

struct ShiftsView: View {
    let shifts: [Shift]
    @Binding var mode: ShiftsMode
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("My Shifts")
                        .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                        .padding(.top, 24)
                    
                    ModeToggle(selection: $mode)
                        .padding(.top, 24)
                    
                    switch mode {
                    case .calendar:
                        CalendarModeView(shifts: shifts, selectedDate: $selectedDate)
                            .padding(.top, 16)
                    case .list:
                        ListModeView(shifts: shifts, selectedDate: $selectedDate)
                            .padding(.top, 20)
                    }
                }
                .foregroundStyle(AppColor.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShiftsRoute.self) { route in
                switch route {
                case .addShift(let date):
                    ShiftFormView(mode: .add(date))
                case .editShift(let shift):
                    ShiftFormView(mode: .edit(shift))
                }
            }
        }
    }
}

#Preview("Calendar") {
    ShiftsView(shifts: SampleData.shifts, mode: .constant(.calendar), selectedDate: .constant(.now))
        .environmentObject(ShiftStore.sample)     
}

#Preview("List") {
    ShiftsView(shifts: SampleData.shifts, mode: .constant(.list), selectedDate: .constant(.now))
        .environmentObject(ShiftStore.sample)      
}
