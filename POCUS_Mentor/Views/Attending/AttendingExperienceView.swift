import SwiftUI

struct AttendingExperienceView: View {
    var body: some View {
        TabView {
            AttendingReviewView()
                .tabItem { Label("Queue", systemImage: "tray.full.fill") }

            StudyHomeView()
                .tabItem { Label("Studies", systemImage: "doc.on.doc") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
