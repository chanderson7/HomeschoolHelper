import SwiftUI
import HomeschoolCore

enum NavigationTab: String, CaseIterable, Identifiable {
    case today
    case plan
    case records
    case family
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .plan: return "Plan"
        case .records: return "Records"
        case .family: return "Family"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .plan: return "calendar"
        case .records: return "folder"
        case .family: return "person.2"
        case .settings: return "gearshape"
        }
    }

    var accessibilityID: String {
        switch self {
        case .today: return "tabToday"
        case .plan: return "tabPlan"
        case .records: return "tabRecords"
        case .family: return "tabFamily"
        case .settings: return "tabSettings"
        }
    }
}

struct HomeTabView: View {
    @EnvironmentObject private var store: HomeschoolStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("selectedTab") private var selectedTab: NavigationTab = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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
                adaptiveRootView
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

    @ViewBuilder
    private var adaptiveRootView: some View {
        if horizontalSizeClass == .regular {
            // iPad & Mac layout: Dual-column sidebar navigation
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(selection: Binding(
                    get: { selectedTab },
                    set: { if let val = $0 { selectedTab = val } }
                )) {
                    Section {
                        ForEach(NavigationTab.allCases) { tab in
                            Label(tab.title, systemImage: tab.icon)
                                .tag(tab)
                                .accessibilityIdentifier(tab.accessibilityID)
                        }
                    } header: {
                        Text("Navigation")
                    }
                }
                .navigationTitle("Homeschool")
                .listStyle(.sidebar)
            } detail: {
                detailView(for: selectedTab)
                    .id(selectedTab)
            }
        } else {
            // iPhone layout: Standard bottom tab bar
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label(NavigationTab.today.title, systemImage: NavigationTab.today.icon) }
                    .tag(NavigationTab.today)
                    .accessibilityIdentifier(NavigationTab.today.accessibilityID)

                PlanView()
                    .tabItem { Label(NavigationTab.plan.title, systemImage: NavigationTab.plan.icon) }
                    .tag(NavigationTab.plan)
                    .accessibilityIdentifier(NavigationTab.plan.accessibilityID)

                RecordsView()
                    .tabItem { Label(NavigationTab.records.title, systemImage: NavigationTab.records.icon) }
                    .tag(NavigationTab.records)
                    .accessibilityIdentifier(NavigationTab.records.accessibilityID)

                FamilyView()
                    .tabItem { Label(NavigationTab.family.title, systemImage: NavigationTab.family.icon) }
                    .tag(NavigationTab.family)
                    .accessibilityIdentifier(NavigationTab.family.accessibilityID)

                SettingsView()
                    .tabItem { Label(NavigationTab.settings.title, systemImage: NavigationTab.settings.icon) }
                    .tag(NavigationTab.settings)
                    .accessibilityIdentifier(NavigationTab.settings.accessibilityID)
            }
        }
    }

    @ViewBuilder
    private func detailView(for tab: NavigationTab) -> some View {
        switch tab {
        case .today:
            TodayView()
        case .plan:
            PlanView()
        case .records:
            RecordsView()
        case .family:
            FamilyView()
        case .settings:
            SettingsView()
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
