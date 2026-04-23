// FILE: CodexMobileApp.swift
// Purpose: App entry point and root dependency wiring.
// Layer: App
// Exports: CodexMobileApp

import SwiftUI

@MainActor
@main
struct CodexMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(CodexMobileAppDelegate.self) private var appDelegate
    @State private var codexService: CodexService

    init() {
        let service = CodexService()
        service.configureNotifications()
        _codexService = State(initialValue: service)
    }

    var body: some Scene {
        WindowGroup {
            if CodexMobileUITestFixtureConfiguration.isEnabled {
                CodexMobileUITestTimelineFixtureView(configuration: .current)
            } else {
                ContentView()
                    .environment(codexService)
                    .onOpenURL { url in
                        Task { @MainActor in
                            guard CodexService.legacyGPTLoginCallbackEnabled else {
                                return
                            }
                            await codexService.handleGPTLoginCallbackURL(url)
                        }
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: UIApplication.didReceiveMemoryWarningNotification
                        )
                    ) { _ in
                        TurnCacheManager.resetAll()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        guard newPhase == .background else { return }
                        TurnCacheManager.resetAll()
                    }
            }
        }
    }
}

private struct CodexMobileUITestFixtureConfiguration {
    let messageCount: Int
    let autoStream: Bool

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-CodexUITestsFixture")
    }

    static var current: Self {
        let arguments = ProcessInfo.processInfo.arguments
        let count = value(after: "-CodexUITestsMessageCount", in: arguments)
            .flatMap(Int.init) ?? 500
        return Self(
            messageCount: max(1, count),
            autoStream: arguments.contains("-CodexUITestsAutoStream")
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }
}

private struct CodexMobileUITestTimelineFixtureView: View {
    let configuration: CodexMobileUITestFixtureConfiguration
    @State private var streamedRows = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(0..<configuration.messageCount, id: \.self) { index in
                    fixtureRow(index: index)
                }
                ForEach(0..<streamedRows, id: \.self) { index in
                    fixtureRow(index: configuration.messageCount + index)
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("turn.timeline.scrollview")
        .task {
            guard configuration.autoStream else { return }
            for step in 1...80 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                streamedRows = step
            }
        }
    }

    private func fixtureRow(index: Int) -> some View {
        Text("Fixture message \(index) - Mobidex timeline performance row with deterministic content.")
            .font(.system(size: 15, weight: index.isMultiple(of: 3) ? .semibold : .regular))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(index.isMultiple(of: 2) ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
