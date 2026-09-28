// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../src/Pauser.sol";
import "../mocks/MockEYE.sol";

/// Mirrors the live contracts (StableStakerV2, Antimatter, PhlimboV3): OZ Pausable, pause by the
/// pauser OR the owner (PhlimboV3), unpause by owner or pauser. OZ `_pause` reverts EnforcedPause
/// when already paused, unlike the repo's idempotent MockPausable.
contract OZPausable is Pausable, Ownable {
    address public pauser;
    constructor(address p) Ownable(msg.sender) { pauser = p; }
    function pause() external { require(msg.sender == pauser || msg.sender == owner(), "auth"); _pause(); }
    function unpause() external { require(msg.sender == pauser || msg.sender == owner(), "auth"); _unpause(); }
}

contract GlobalPauseAllOrNothingTest is Test {
    Pauser pauser;
    MockEYE eye;
    OZPausable a;
    OZPausable b;
    address guardian = address(0xBEEF);

    function setUp() public {
        eye = new MockEYE();
        pauser = new Pauser(address(eye));
        a = new OZPausable(address(pauser));
        b = new OZPausable(address(pauser));
        pauser.register(address(a));
        pauser.register(address(b));
        eye.mint(guardian, 10_000e18);
        vm.prank(guardian);
        eye.approve(address(pauser), type(uint256).max);
    }

    /// One registered contract already paused (e.g. the owner paused PhlimboV3 directly) makes the
    /// permissionless global pause revert for EVERY contract, so nothing else can be stopped.
    function test_audit_onePrePausedContractBlocksGlobalPause() public {
        a.pause(); // owner pauses one contract on its own
        vm.prank(guardian);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pauser.pause();
        assertFalse(b.paused(), "b could not be paused");
    }

    /// After a global pause, the owner unpausing any single contract makes Pauser.unpause revert.
    function test_audit_oneEarlyUnpauseBlocksGlobalUnpause() public {
        vm.prank(guardian);
        pauser.pause();
        b.unpause(); // owner brings one contract back early
        vm.expectRevert(Pausable.ExpectedPause.selector);
        pauser.unpause();
        assertTrue(a.paused(), "a stays paused");
    }
}
