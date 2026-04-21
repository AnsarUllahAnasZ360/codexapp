// FILE: TurnViewModelGitBranchWorktreeTests.swift
// Purpose: Verifies worktree-backed branches are exposed to the UI only when Git reports them as checked out elsewhere.
// Layer: Unit Test
// Exports: TurnViewModelGitBranchWorktreeTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

@MainActor
final class TurnViewModelGitBranchWorktreeTests: XCTestCase {
    func testWorktreePathResolvesOnlyForBranchesCheckedOutElsewhere() {
        let viewModel = TurnViewModel()
        viewModel.gitBranchesCheckedOutElsewhere = ["mobidex/feature-a"]
        viewModel.gitWorktreePathsByBranch = [
            "mobidex/feature-a": "/tmp/mobidex-feature-a",
            "main": "/tmp/mobidex-main"
        ]

        XCTAssertEqual(
            viewModel.worktreePathForCheckedOutElsewhereBranch("mobidex/feature-a"),
            "/tmp/mobidex-feature-a"
        )
        XCTAssertNil(viewModel.worktreePathForCheckedOutElsewhereBranch("main"))
        XCTAssertNil(viewModel.worktreePathForCheckedOutElsewhereBranch("mobidex/missing"))
    }

    func testApplyGitBranchTargetsStoresTrueLocalCheckoutPath() {
        let viewModel = TurnViewModel()
        let result = GitBranchesWithStatusResult(
            from: [
                "branches": .array([.string("main")]),
                "branchesCheckedOutElsewhere": .array([]),
                "worktreePathByBranch": .object([:]),
                "localCheckoutPath": .string("/tmp/mobidex-local/phodex-bridge"),
                "current": .string("main"),
                "default": .string("main"),
            ]
        )

        viewModel.applyGitBranchTargets(result)

        XCTAssertEqual(viewModel.gitLocalCheckoutPath, "/tmp/mobidex-local/phodex-bridge")
    }

    func testApplyGitBranchTargetsKeepsSelectedBaseBranchEmptyWhenDefaultIsRemoteOnly() {
        let viewModel = TurnViewModel()
        let result = GitBranchesWithStatusResult(
            from: [
                "branches": .array([.string("mobidex/topic")]),
                "branchesCheckedOutElsewhere": .array([]),
                "worktreePathByBranch": .object([:]),
                "localCheckoutPath": .string("/tmp/mobidex-local/phodex-bridge"),
                "current": .string("mobidex/topic"),
                "default": .string("main"),
            ]
        )

        viewModel.applyGitBranchTargets(result)

        XCTAssertEqual(viewModel.gitDefaultBranch, "main")
        XCTAssertEqual(viewModel.selectedGitBaseBranch, "")
    }

    func testApplyGitBranchTargetsPreservesValidLocalBaseBranchSelection() {
        let viewModel = TurnViewModel()
        viewModel.selectedGitBaseBranch = "release/1.0"
        let result = GitBranchesWithStatusResult(
            from: [
                "branches": .array([.string("main"), .string("release/1.0"), .string("mobidex/topic")]),
                "branchesCheckedOutElsewhere": .array([]),
                "worktreePathByBranch": .object([:]),
                "localCheckoutPath": .string("/tmp/mobidex-local/phodex-bridge"),
                "current": .string("mobidex/topic"),
                "default": .string("main"),
            ]
        )

        viewModel.applyGitBranchTargets(result)

        XCTAssertEqual(viewModel.selectedGitBaseBranch, "release/1.0")
    }
}
