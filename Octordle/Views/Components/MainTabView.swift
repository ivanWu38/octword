import SwiftUI

/// Tab enumeration for 4-tab structure
enum Tab: String, CaseIterable {
    case today          // Daily Challenge
    case unlimited      // Unlimited practice
    case journey        // Stats/Journey
    case settings       // Settings

    var title: String {
        switch self {
        case .today: return "Today"
        case .unlimited: return "Unlimited"
        case .journey: return "Journey"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .unlimited: return "infinity"
        case .journey: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }

    var index: Int {
        switch self {
        case .today: return 0
        case .unlimited: return 1
        case .journey: return 2
        case .settings: return 3
        }
    }
}

/// Main tab navigation view with 3 tabs
struct MainTabView: View {
    @State private var selectedTab: Tab = .today
    @State private var hideTabBar = false

    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService

    init() {
        // Hide the default tab bar
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $selectedTab) {
                DailyView()
                    .tag(Tab.today)

                UnlimitedView()
                    .tag(Tab.unlimited)

                StatsView()
                    .tag(Tab.journey)

                SettingsView()
                    .tag(Tab.settings)
            }

            // Custom tab bar (only show when not hidden)
            if !hideTabBar {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideTabBar)) { _ in
            hideTabBar = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTabBar)) { _ in
            hideTabBar = false
        }
    }
}

/// Custom tab bar with 4 tabs
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Environment(\.colorScheme) private var colorScheme
    @State private var rippleTab: Tab? = nil
    @State private var rippleScale: CGFloat = 0.1
    @State private var rippleOpacity: CGFloat = 0.4

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.quordleCardBorder)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
        }
        .background(
            Color.quordleTabBarBackground
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(for tab: Tab) -> some View {
        Button {
            if selectedTab != tab {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                }
                HapticManager.shared.tabSwitch()
                triggerRipple(for: tab)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .quordlePrimary : .quordleTabInactive)

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .quordlePrimary : .quordleTabInactive)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .overlay(
                Circle()
                    .fill(Color.quordlePrimary)
                    .scaleEffect(rippleTab == tab ? rippleScale : 0.1)
                    .opacity(rippleTab == tab ? rippleOpacity : 0)
                    .allowsHitTesting(false)
            )
            .clipped()
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.9))
    }

    private func triggerRipple(for tab: Tab) {
        rippleScale = 0.1
        rippleOpacity = 0.25
        rippleTab = tab

        withAnimation(.easeOut(duration: 0.45)) {
            rippleScale = 2.5
            rippleOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if rippleTab == tab {
                rippleTab = nil
            }
        }
    }
}

// MARK: - Notifications for tab bar visibility
extension Notification.Name {
    static let hideTabBar = Notification.Name("hideTabBar")
    static let showTabBar = Notification.Name("showTabBar")
}

#Preview {
    MainTabView()
        .environmentObject(ThemeService.shared)
        .environmentObject(SubscriptionService.shared)
        .environmentObject(StatsService.shared)
}
