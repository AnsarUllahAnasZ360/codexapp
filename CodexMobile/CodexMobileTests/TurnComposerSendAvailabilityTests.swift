// FILE: TurnComposerSendAvailabilityTests.swift
// Purpose: Locks send-button enable/disable truth table after composer refactor.
// Layer: Unit Test
// Exports: TurnComposerSendAvailabilityTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

@MainActor
final class TurnComposerSendAvailabilityTests: XCTestCase {
    private static var retainedServices: [CodexService] = []

    func testSendDisabledWhenDisconnected() {
        let state = makeState(isConnected: false)
        XCTAssertTrue(state.isSendDisabled)
    }

    func testSendDisabledWhenSendingInFlight() {
        let state = makeState(isSending: true)
        XCTAssertTrue(state.isSendDisabled)
    }

    func testSendEnabledWhenActiveTurnExistsAndPayloadIsValid() {
        let state = makeState(trimmedInput: "queue this")
        XCTAssertFalse(state.isSendDisabled)
    }

    func testSendDisabledWhenInputAndImagesAreEmpty() {
        let state = makeState(trimmedInput: "", hasReadyImages: false)
        XCTAssertTrue(state.isSendDisabled)
    }

    func testSendDisabledWhenAttachmentStateIsBlocking() {
        let state = makeState(hasBlockingAttachmentState: true)
        XCTAssertTrue(state.isSendDisabled)
    }

    func testSendEnabledWhenConnectedAndPayloadIsValid() {
        let textState = makeState(trimmedInput: "Ship it", hasReadyImages: false)
        XCTAssertFalse(textState.isSendDisabled)

        let imageState = makeState(trimmedInput: "", hasReadyImages: true)
        XCTAssertFalse(imageState.isSendDisabled)
    }

    func testSendEnabledWhenReviewSelectionIsPresentWithoutText() {
        let reviewState = makeState(trimmedInput: "", hasReadyImages: false, hasReviewSelection: true)
        XCTAssertFalse(reviewState.isSendDisabled)
    }

    func testSendEnabledWhenSubagentsSelectionIsPresentWithoutText() {
        let subagentsState = makeState(trimmedInput: "", hasReadyImages: false, hasSubagentsSelection: true)
        XCTAssertFalse(subagentsState.isSendDisabled)
    }

    func testSendDisabledWhileReviewSelectionIsWaitingForTarget() {
        let reviewState = makeState(
            trimmedInput: "follow up",
            hasReadyImages: false,
            hasReviewSelection: false,
            hasPendingReviewSelection: true
        )
        XCTAssertTrue(reviewState.isSendDisabled)
    }

    func testSendTurnRestoresRawDraftWhenStartTurnFails() async {
        let service = makeService()
        service.isConnected = true

        let viewModel = TurnViewModel()
        let rawInput = "Please update @TurnView.swift"
        let rawMention = TurnComposerMentionedFile(
            fileName: "TurnView.swift",
            path: "Views/Turn/TurnView.swift"
        )
        let attachment = CodexImageAttachment(
            thumbnailBase64JPEG: "thumb",
            payloadDataURL: "data:image/jpeg;base64,AAAA"
        )

        viewModel.input = rawInput
        viewModel.composerMentionedFiles = [rawMention]
        viewModel.composerAttachments = [
            TurnComposerImageAttachment(id: "attachment-1", state: .ready(attachment))
        ]

        viewModel.sendTurn(codex: service, threadID: "thread-send-failure")
        await waitForSendCompletion(viewModel)

        XCTAssertFalse(viewModel.isSending)
        XCTAssertEqual(viewModel.input, rawInput)
        XCTAssertEqual(viewModel.composerMentionedFiles, [rawMention])
        XCTAssertEqual(viewModel.readyComposerAttachments, [attachment])
        XCTAssertEqual(viewModel.composerAttachments.count, 1)
    }

    func testSendTurnUsesCannedPromptWhenSubagentsChipIsSelected() async {
        let service = makeService()
        service.isConnected = true
        service.resumedThreadIDs.insert("thread-subagents")

        var capturedParams: JSONValue?
        service.requestTransportOverride = { method, params in
            XCTAssertEqual(method, "turn/start")
            capturedParams = params
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-subagents")]),
                includeJSONRPC: false
            )
        }

        let viewModel = TurnViewModel()
        viewModel.input = "/sub"
        viewModel.slashCommandPanelState = .commands(query: "sub")
        viewModel.onSelectSlashCommand(.subagents)

        viewModel.sendTurn(codex: service, threadID: "thread-subagents")
        await waitForSendCompletion(viewModel)

        XCTAssertEqual(
            textInput(from: capturedParams),
            "Run subagents for different tasks. Delegate distinct work in parallel when helpful and then synthesize the results."
        )
    }

    func testSendTurnPrefixesDraftTextWhenSubagentsChipIsSelected() async {
        let service = makeService()
        service.isConnected = true
        service.resumedThreadIDs.insert("thread-literal-subagents")

        var capturedParams: JSONValue?
        service.requestTransportOverride = { method, params in
            XCTAssertEqual(method, "turn/start")
            capturedParams = params
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-literal-subagents")]),
                includeJSONRPC: false
            )
        }

        let viewModel = TurnViewModel()
        viewModel.input = "/sub"
        viewModel.slashCommandPanelState = .commands(query: "sub")
        viewModel.onSelectSlashCommand(.subagents)

        viewModel.input = "Please explain what /subagents does."

        viewModel.sendTurn(codex: service, threadID: "thread-literal-subagents")
        await waitForSendCompletion(viewModel)

        XCTAssertEqual(
            textInput(from: capturedParams),
            "Run subagents for different tasks. Delegate distinct work in parallel when helpful and then synthesize the results.\n\nPlease explain what /subagents does."
        )
    }

    func testSendTurnPrefixesPromptBeforeOrdinaryDraftText() async {
        let service = makeService()
        service.isConnected = true
        service.resumedThreadIDs.insert("thread-shifted-subagents")

        var capturedParams: JSONValue?
        service.requestTransportOverride = { method, params in
            XCTAssertEqual(method, "turn/start")
            capturedParams = params
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-shifted-subagents")]),
                includeJSONRPC: false
            )
        }

        let viewModel = TurnViewModel()
        viewModel.input = "Please explain /subagents too."
        viewModel.isSubagentsSelectionArmed = true

        viewModel.sendTurn(codex: service, threadID: "thread-shifted-subagents")
        await waitForSendCompletion(viewModel)

        XCTAssertEqual(
            textInput(from: capturedParams),
            "Run subagents for different tasks. Delegate distinct work in parallel when helpful and then synthesize the results.\n\nPlease explain /subagents too."
        )
    }

    func testSendTurnTrimsLeadingWhitespaceBeforeApplyingSubagentsPrompt() async {
        let service = makeService()
        service.isConnected = true
        service.resumedThreadIDs.insert("thread-trimmed-subagents")

        var capturedParams: JSONValue?
        service.requestTransportOverride = { method, params in
            XCTAssertEqual(method, "turn/start")
            capturedParams = params
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-trimmed-subagents")]),
                includeJSONRPC: false
            )
        }

        let viewModel = TurnViewModel()
        viewModel.input = "   follow up"
        viewModel.isSubagentsSelectionArmed = true

        viewModel.sendTurn(codex: service, threadID: "thread-trimmed-subagents")
        await waitForSendCompletion(viewModel)

        XCTAssertEqual(
            textInput(from: capturedParams),
            "Run subagents for different tasks. Delegate distinct work in parallel when helpful and then synthesize the results.\n\nfollow up"
        )
    }

    func testSendTurnPrefixesPromptAfterFileMentionRewrite() async {
        let service = makeService()
        service.isConnected = true
        service.resumedThreadIDs.insert("thread-file-mention-subagents")

        var capturedParams: JSONValue?
        service.requestTransportOverride = { method, params in
            XCTAssertEqual(method, "turn/start")
            capturedParams = params
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-file-mention-subagents")]),
                includeJSONRPC: false
            )
        }

        let viewModel = TurnViewModel()
        viewModel.input = "@TurnView.swift /sub"
        viewModel.composerMentionedFiles = [
            TurnComposerMentionedFile(
                fileName: "TurnView.swift",
                path: "Views/Turn/TurnView.swift"
            )
        ]
        viewModel.slashCommandPanelState = .commands(query: "sub")
        viewModel.onSelectSlashCommand(.subagents)

        viewModel.sendTurn(codex: service, threadID: "thread-file-mention-subagents")
        await waitForSendCompletion(viewModel)

        XCTAssertEqual(
            textInput(from: capturedParams),
            "Run subagents for different tasks. Delegate distinct work in parallel when helpful and then synthesize the results.\n\n@Views/Turn/TurnView.swift"
        )
    }

    func testCanSendMoreThanTenTurnsWithoutFreeAccessLimit() async {
        let service = makeService()
        service.isConnected = true
        var capturedInputs: [String] = []
        service.requestTransportOverride = { [weak self] method, params in
            XCTAssertEqual(method, "turn/start")
            capturedInputs.append(self?.textInput(from: params) ?? "")
            return RPCMessage(
                id: .string(UUID().uuidString),
                result: .object(["turnId": .string("turn-\(capturedInputs.count)")]),
                includeJSONRPC: false
            )
        }

        for index in 1...12 {
            let threadID = "thread-free-access-\(index)"
            let viewModel = TurnViewModel()
            service.resumedThreadIDs.insert(threadID)
            viewModel.input = "Free access verification message \(index)"
            viewModel.sendTurn(codex: service, threadID: threadID)
            await waitForSendCompletion(viewModel)

            XCTAssertFalse(viewModel.isSending)
            XCTAssertFalse(
                (service.lastErrorMessage ?? "").localizedCaseInsensitiveContains("Pro"),
                "Message \(index) should not hit a Pro access restriction."
            )
        }

        XCTAssertEqual(capturedInputs.count, 12)
        XCTAssertEqual(capturedInputs.first, "Free access verification message 1")
        XCTAssertEqual(capturedInputs.last, "Free access verification message 12")
    }

    func testSecureHandshakeTranscriptKeepsBridgeCompatibleWireTag() {
        XCTAssertEqual(codexSecureHandshakeTag, "remodex-e2ee-v1")

        let transcript = codexSecureTranscriptBytes(
            sessionId: "session-wire-contract",
            protocolVersion: codexSecureProtocolVersion,
            handshakeMode: .qrBootstrap,
            keyEpoch: 1,
            macDeviceId: "mac-wire-contract",
            phoneDeviceId: "phone-wire-contract",
            macIdentityPublicKey: Data(repeating: 1, count: 32).base64EncodedString(),
            phoneIdentityPublicKey: Data(repeating: 2, count: 32).base64EncodedString(),
            macEphemeralPublicKey: Data(repeating: 3, count: 32).base64EncodedString(),
            phoneEphemeralPublicKey: Data(repeating: 4, count: 32).base64EncodedString(),
            clientNonce: Data(repeating: 5, count: 32),
            serverNonce: Data(repeating: 6, count: 32),
            expiresAtForTranscript: 1_776_918_000_000
        )

        let tagBytes = Data("remodex-e2ee-v1".utf8)
        XCTAssertEqual(transcript.prefix(4), Data([0, 0, 0, UInt8(tagBytes.count)]))
        XCTAssertEqual(transcript.dropFirst(4).prefix(tagBytes.count), tagBytes)
    }

    func testPaymentRuntimeAndBuildHooksAreAbsent() throws {
        let deletedPaymentPaths = [
            "CodexMobile/CodexMobile/Services/Payments/SubscriptionService.swift",
            "CodexMobile/CodexMobile/Services/Payments/RevenueCatDisplayExtensions.swift",
            "CodexMobile/CodexMobile/Views/Payments/SubscriptionGateView.swift",
            "CodexMobile/CodexMobile/Views/Payments/RevenueCatPaywallView.swift",
            "CodexMobile/CodexMobileTests/SubscriptionServiceAccessTests.swift",
        ]

        for path in deletedPaymentPaths {
            XCTAssertFalse(
                fileExists(path),
                "\(path) should stay removed because it only served subscription/paywall flows."
            )
        }

        let checkedFiles = [
            "CodexMobile/BuildSupport/Base.xcconfig",
            "CodexMobile/BuildSupport/CodexMobile-Info.plist",
            "CodexMobile/CodexMobile.xcodeproj/project.pbxproj",
            "CodexMobile/CodexMobile.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
            "CodexMobile/CodexMobile/CodexMobileApp.swift",
            "CodexMobile/CodexMobile/ContentView.swift",
            "CodexMobile/CodexMobile/Services/AppEnvironment.swift",
            "CodexMobile/CodexMobile/Views/SettingsView.swift",
            "CodexMobile/CodexMobile/Views/Turn/TurnView.swift",
            "CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift",
        ]
        let forbiddenTokens = [
            "RevenueCat",
            "StoreKit",
            "Purchases.",
            "SubscriptionService",
            "SubscriptionGateView",
            "RevenueCatPaywallView",
            "REVENUECAT",
            "hasAppAccess",
            "hasProAccess",
            "freeSend",
            "Upgrade to Pro",
            "Mobidex Pro",
        ]

        for path in checkedFiles {
            let contents = try sourceText(path)
            for token in forbiddenTokens {
                XCTAssertFalse(
                    contents.contains(token),
                    "\(path) should not reference removed payment/access token \(token)."
                )
            }
        }
    }

    func testRootAndComposerFlowNoLongerReferenceAccessGate() throws {
        let rootContent = try sourceText("CodexMobile/CodexMobile/ContentView.swift")
        XCTAssertTrue(rootContent.contains("if !hasSeenOnboarding"))
        XCTAssertTrue(rootContent.contains("} else if shouldShowQRScanner {"))
        XCTAssertFalse(rootContent.contains("bootstrapState"))
        XCTAssertFalse(rootContent.contains("SubscriptionGateView"))

        let turnView = try sourceText("CodexMobile/CodexMobile/Views/Turn/TurnView.swift")
        XCTAssertTrue(turnView.contains("viewModel.sendTurn(codex: codex, threadID: thread.id)"))
        XCTAssertFalse(turnView.contains("subscriptions:"))

        let turnViewModel = try sourceText("CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift")
        XCTAssertTrue(turnViewModel.contains("func sendTurn(\n        codex: CodexService,\n        threadID: String"))
        XCTAssertFalse(turnViewModel.contains("Your 5 free messages are over"))
        XCTAssertFalse(turnViewModel.contains("consumeFreeSendAttemptIfNeeded"))
    }

    func testFormerProFeaturesRemainWiredAfterPaywallRemoval() throws {
        assertSource("CodexMobile/CodexMobile/Views/SettingsView.swift", contains: [
            "Picker(\"Speed\"",
            "runtimeServiceTierSelection",
            "Picker(\"Access\"",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnComposerRuntimeMenuBuilder.swift", contains: [
            "makeSpeedMenu",
            "CodexServiceTier.allCases",
            "runtimeActions.selectServiceTier",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnGitActionsToolbar.swift", contains: [
            "TurnGitActionsToolbarButton",
            "commitAndPush",
            "createPR",
        ])
        assertSource("CodexMobile/CodexMobile/Services/GitActionsService.swift", contains: [
            "func commit",
            "func push",
            "func pull",
            "func checkout",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnView.swift", contains: [
            "startVoiceRecordingIfReady",
            "voiceTranscriptionManager",
            "CodexVoiceFailureReason",
        ])
        assertSource("CodexMobile/CodexMobile/Services/GPTVoiceTranscriptionManager.swift", contains: [
            "func startRecording",
            "func stopRecording",
            "targetSampleRate",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnComposerCommandState.swift", contains: [
            "case subagents",
            "allCommands",
            "Insert a canned prompt",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift", contains: [
            "applyingSubagentsSelection",
            "buildPayloadWithMentions",
            "isSubagentsSelectionArmed",
        ])
        assertSource("CodexMobile/CodexMobile/Services/CodexService+ThreadsTurns.swift", contains: [
            "func listSkills",
            "skills/list",
            "func fuzzyFileSearch",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/SkillAutocompletePanel.swift", contains: [
            "SkillAutocompletePanel",
            "onSelect(skill)",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/FileAutocompletePanel.swift", contains: [
            "FileAutocompletePanel",
            "onSelect(item)",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Turn/TurnComposerView.swift", contains: [
            "Ask anything... @files, $skills, /commands",
        ])
        assertSource("CodexMobile/CodexMobile/Views/QRScannerView.swift", contains: [
            "validatePairingQRCode",
            "onScan(payload)",
        ])
        assertSource("CodexMobile/CodexMobile/Views/Home/ContentViewModel.swift", contains: [
            "connectWithAutoRecovery",
            "codex.connect",
        ])
    }

    private func makeState(
        isSending: Bool = false,
        isConnected: Bool = true,
        trimmedInput: String = "hello",
        hasReadyImages: Bool = false,
        hasBlockingAttachmentState: Bool = false,
        hasReviewSelection: Bool = false,
        hasPendingReviewSelection: Bool = false,
        hasSubagentsSelection: Bool = false
    ) -> TurnComposerSendAvailability {
        TurnComposerSendAvailability(
            isSending: isSending,
            isConnected: isConnected,
            trimmedInput: trimmedInput,
            hasReadyImages: hasReadyImages,
            hasBlockingAttachmentState: hasBlockingAttachmentState,
            hasReviewSelection: hasReviewSelection,
            hasPendingReviewSelection: hasPendingReviewSelection,
            hasSubagentsSelection: hasSubagentsSelection
        )
    }

    private func waitForSendCompletion(_ viewModel: TurnViewModel, maxPollCount: Int = 120) async {
        for _ in 0..<maxPollCount where viewModel.isSending {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func textInput(from params: JSONValue?) -> String? {
        params?
            .objectValue?["input"]?
            .arrayValue?
            .compactMap(\.objectValue)
            .first(where: { $0["type"]?.stringValue == "text" })?["text"]?
            .stringValue
    }

    private func makeService() -> CodexService {
        let suiteName = "TurnComposerSendAvailabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let service = CodexService(defaults: defaults)
        service.messagesByThread = [:]

        // CodexService currently crashes while deallocating in unit-test environment.
        // Keep instances alive for process lifetime so assertions remain deterministic.
        Self.retainedServices.append(service)
        return service
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func fileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent(relativePath).path)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func assertSource(
        _ relativePath: String,
        contains requiredTokens: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let contents = try sourceText(relativePath)
            for token in requiredTokens {
                XCTAssertTrue(
                    contents.contains(token),
                    "\(relativePath) should still contain \(token).",
                    file: file,
                    line: line
                )
            }
        } catch {
            XCTFail("Could not read \(relativePath): \(error)", file: file, line: line)
        }
    }
}
