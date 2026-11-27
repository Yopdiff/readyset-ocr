import SwiftUI

enum AppTab: Hashable {
    case home, shifts, settings
}

enum ShiftsMode: Hashable {
    case calendar, list
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var shiftsMode: ShiftsMode = .calendar
    @State private var shiftsFocusDate: Date = .now
    
    @StateObject private var store = ShiftStore.persistent()   // 기기에 저장된 데이터
    @Environment(\.scenePhase) private var scenePhase          // 앱이 화면에 있는지
    @State private var hasSeenStorageWarning = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                shifts: store.shifts,
                onOpenCalendar: { date in
                    shiftsFocusDate = date
                    shiftsMode = .calendar
                    selectedTab = .shifts
                },
                onOpenList: {
                    shiftsFocusDate = .now
                    shiftsMode = .list
                    selectedTab = .shifts
                }
            )
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)
            
            ShiftsView(shifts: store.shifts, mode: $shiftsMode, selectedDate: $shiftsFocusDate)
                .tabItem { Label("Shifts", systemImage: "calendar") }
                .tag(AppTab.shifts)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(AppColor.primary)
        .preferredColorScheme(.light)
        .environmentObject(store)
        // 앱으로 돌아올 때마다 (권한 창을 닫은 직후 포함) 리마인더 다시 맞추기
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshReminders()
            }
        }
        // 저장소를 못 열었으면 알려 주기 (조용히 넘어가면 알람이 안 울리는 걸 사용자가 몰라요)
        .alert(
            "Couldn't open your saved shifts",
            isPresented: Binding(
                get: { store.isUsingTemporaryStorage && !hasSeenStorageWarning },
                set: { if !$0 { hasSeenStorageWarning = true } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Shifts you add now won't be saved, and wake-up alarms won't be set. Please close and reopen the app.")
        }
    }
}

#Preview {
    ContentView()
}
