import SwiftUI

struct SettingsDetailPlaceholder: View {
    let title: String
    
    var body: some View {
        Text("\(title) — coming soon")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}
