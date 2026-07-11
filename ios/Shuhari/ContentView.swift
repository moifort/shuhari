import SwiftUI

enum TabSelection: Int, CaseIterable, Identifiable {
    case carnet, importer
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .carnet: "Carnet"
        case .importer: "Importer"
        }
    }
    var icon: String {
        switch self {
        case .carnet: "book"
        case .importer: "plus.circle"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .carnet

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(TabSelection.carnet.label, systemImage: TabSelection.carnet.icon, value: .carnet) {
                HomeView()
            }
            .accessibilityIdentifier("tab-carnet")
            Tab(TabSelection.importer.label, systemImage: TabSelection.importer.icon, value: .importer) {
                ImportView()
            }
            .accessibilityIdentifier("tab-importer")
        }
    }
}

#Preview {
    ContentView()
}
