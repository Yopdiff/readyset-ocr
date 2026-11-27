import SwiftUI

enum SampleData {
    static let cafe = Workplace(name: "Café A", nameOnSchedule: "Jamie Park", color: .orange)
    static let restaurant = Workplace(name: "Restaurant B", nameOnSchedule: "Taylor", color: .blue)
    
    static var shifts: [Shift] {
        [
            makeShift(cafe,       daysFromToday: 1, start: (6, 0),  end: (13, 30)),
            makeShift(restaurant, daysFromToday: 2, start: (17, 0), end: (22, 0)),
            makeShift(cafe,       daysFromToday: 4, start: (6, 0),  end: (13, 30)),
            makeShift(restaurant, daysFromToday: 6, start: (22, 0), end: (6, 0)),   // 밤샘 근무
        ]
    }
    
    /// "오늘부터 며칠 뒤, 몇 시~몇 시" 근무를 만드는 도우미
    private static func makeShift(
        _ workplace: Workplace,
        daysFromToday: Int,
        start: (hour: Int, minute: Int),
        end: (hour: Int, minute: Int)
    ) -> Shift {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: daysFromToday, to: today)!
        
        let startDate = calendar.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day)!
        var endDate = calendar.date(bySettingHour: end.hour, minute: end.minute, second: 0, of: day)!
        
        // 종료가 시작보다 이르면 다음 날 끝나는 밤샘 근무
        if endDate <= startDate {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
        }
        return Shift(workplace: workplace, start: startDate, end: endDate)
    }
}

// 테스트 데이터와 시간 표기가 제대로 나오는지 확인하는 프리뷰
#Preview {
    List(SampleData.shifts) { shift in
        VStack(alignment: .leading, spacing: 4) {
            Text(shift.start.shortDayText).font(.headline)
            Text(shift.workplace.name)
            Text(shift.timeRangeText).foregroundStyle(.secondary)
        }
    }
}
