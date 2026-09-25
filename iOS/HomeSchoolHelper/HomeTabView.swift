import SwiftUI
import HomeschoolCore

struct HomeTabView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @State private var hasDismissedOnboarding: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] != nil && ProcessInfo.processInfo.environment["HSH_UI_TEST_ONBOARDING"] != "1" {
            return true
        }
        #endif
        return false
    }()

    var body: some View {
        Group {
            if let message = store.loadError {
                LoadFailureView(message: message, retry: store.load)
            } else if store.isStudentModeActive {
                StudentModeView()
            } else if store.state.students.isEmpty && !hasDismissedOnboarding {
                OnboardingView(onExplore: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasDismissedOnboarding = true
                    }
                })
            } else {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.max") }
                        .accessibilityIdentifier("tabToday")
                    PlanView()
                        .tabItem { Label("Plan", systemImage: "calendar") }
                        .accessibilityIdentifier("tabPlan")
                    RecordsView()
                        .tabItem { Label("Records", systemImage: "folder") }
                        .accessibilityIdentifier("tabRecords")
                    FamilyView()
                        .tabItem { Label("Family", systemImage: "person.2") }
                        .accessibilityIdentifier("tabFamily")
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("tabSettings")
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.state.students.isEmpty)
        .alert(item: $store.presentedError) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            setupStoreIntegration()
        }
    }

    private func setupStoreIntegration() {
        store.onSyncDailyReminder = { enabled, time, state in
            Task {
                if enabled {
                    let granted = await NotificationManager.shared.requestAuthorization()
                    if granted {
                        await NotificationManager.shared.scheduleDailyMorningDigest(time: time, state: state)
                    }
                } else {
                    NotificationManager.shared.cancelDailyMorningDigest()
                }
            }
        }
        store.onPortfolioItemDeleted = { fileName in
            PortfolioStorage.shared.deleteImage(fileName: fileName)
        }
    }
}

