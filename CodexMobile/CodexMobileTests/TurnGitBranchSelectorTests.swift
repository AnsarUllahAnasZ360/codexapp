// FILE: TurnGitBranchSelectorTests.swift
// Purpose: Verifies new branch creation names normalize toward the mobidex/ prefix without double-prefixing.
// Layer: Unit Test
// Exports: TurnGitBranchSelectorTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

final class TurnGitBranchSelectorTests: XCTestCase {
    func testNormalizesCreatedBranchNamesTowardMobidexPrefix() {
        XCTAssertEqual(mobidexNormalizedCreatedBranchName("foo"), "mobidex/foo")
        XCTAssertEqual(mobidexNormalizedCreatedBranchName("mobidex/foo"), "mobidex/foo")
        XCTAssertEqual(mobidexNormalizedCreatedBranchName("  foo  "), "mobidex/foo")
    }

    func testNormalizesEmptyBranchNamesToEmptyString() {
        XCTAssertEqual(mobidexNormalizedCreatedBranchName("   "), "")
    }

    func testCurrentBranchSelectionDisablesCheckedOutElsewhereRowsWhenWorktreePathIsMissing() {
        XCTAssertTrue(
            mobidexCurrentBranchSelectionIsDisabled(
                branch: "mobidex/feature-a",
                currentBranch: "main",
                gitBranchesCheckedOutElsewhere: ["mobidex/feature-a"],
                gitWorktreePathsByBranch: [:],
                allowsSelectingCurrentBranch: true
            )
        )
    }

    func testCurrentBranchSelectionKeepsCheckedOutElsewhereRowsEnabledWhenWorktreePathExists() {
        XCTAssertFalse(
            mobidexCurrentBranchSelectionIsDisabled(
                branch: "mobidex/feature-a",
                currentBranch: "main",
                gitBranchesCheckedOutElsewhere: ["mobidex/feature-a"],
                gitWorktreePathsByBranch: ["mobidex/feature-a": "/tmp/mobidex-feature-a"],
                allowsSelectingCurrentBranch: true
            )
        )
    }

    func testSelectableDefaultBranchReturnsNilWhenDefaultIsNotLocal() {
        XCTAssertNil(
            mobidexSelectableDefaultBranch(
                defaultBranch: "main",
                availableGitBranchTargets: ["mobidex/feature-a"]
            )
        )
    }

    func testSelectableDefaultBranchReturnsDefaultWhenItIsLocal() {
        XCTAssertEqual(
            mobidexSelectableDefaultBranch(
                defaultBranch: "main",
                availableGitBranchTargets: ["main", "mobidex/feature-a"]
            ),
            "main"
        )
    }
}
