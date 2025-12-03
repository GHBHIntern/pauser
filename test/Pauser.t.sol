// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Pauser.sol";
import "../src/interfaces/IPauser.sol";
import "../src/interfaces/IPausable.sol";
import "./mocks/MockEYE.sol";
import "./mocks/MockPausable.sol";

/**
 * @title PauserTest
 * @notice Comprehensive test suite for the Global Pauser contract (Red Phase - TDD)
 * @dev All tests should FAIL in red phase as functions are stubbed
 */
contract PauserTest is Test {
    Pauser public pauser;
    MockEYE public eyeToken;
    MockPausable public pausable1;
    MockPausable public pausable2;
    MockPausable public pausable3;

    address public owner;
    address public user1;
    address public user2;

    uint256 constant DEFAULT_BURN_AMOUNT = 1000 * 1e18;
    address constant DEAD_ADDRESS = address(0xdead);

    // ============ SETUP ============

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock EYE token
        eyeToken = new MockEYE();

        // Deploy Pauser contract
        pauser = new Pauser(address(eyeToken));

        // Deploy mock pausable contracts (authorize pauser to pause them)
        pausable1 = new MockPausable(address(pauser));
        pausable2 = new MockPausable(address(pauser));
        pausable3 = new MockPausable(address(pauser));

        // Mint EYE to users for testing
        eyeToken.mint(user1, 10000 * 1e18);
        eyeToken.mint(user2, 10000 * 1e18);

        // Approve pauser to spend EYE on behalf of users
        vm.prank(user1);
        eyeToken.approve(address(pauser), type(uint256).max);

        vm.prank(user2);
        eyeToken.approve(address(pauser), type(uint256).max);
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_constructor_setsEyeToken() public {
        assertEq(pauser.eyeToken(), address(eyeToken), "EYE token should be set correctly");
    }

    function test_constructor_setsDefaultBurnAmount() public {
        assertEq(pauser.eyeBurnAmount(), DEFAULT_BURN_AMOUNT, "Default burn amount should be 1000 EYE");
    }

    function test_constructor_setsOwner() public {
        assertEq(pauser.owner(), owner, "Owner should be msg.sender");
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert();
        new Pauser(address(0));
    }

    // ============ REGISTRATION TESTS ============

    function test_register_addsContractToArray() public {
        pauser.register(address(pausable1));

        address[] memory contracts = pauser.getPausableContracts();
        assertEq(contracts.length, 1, "Should have 1 registered contract");
        assertEq(contracts[0], address(pausable1), "Should be pausable1");
    }

    function test_register_setsIsRegisteredTrue() public {
        pauser.register(address(pausable1));

        assertTrue(pauser.isRegistered(address(pausable1)), "isRegistered should be true");
    }

    function test_register_emitsContractRegisteredEvent() public {
        vm.expectEmit(true, false, false, false);
        emit IPauser.ContractRegistered(address(pausable1));

        pauser.register(address(pausable1));
    }

    function test_register_revertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pauser.register(address(pausable1));
    }

    function test_register_revertsIfZeroAddress() public {
        vm.expectRevert();
        pauser.register(address(0));
    }

    function test_register_revertsIfAlreadyRegistered() public {
        pauser.register(address(pausable1));

        vm.expectRevert();
        pauser.register(address(pausable1));
    }

    // ============ UNREGISTRATION TESTS ============

    function test_unregister_removesContractFromArray() public {
        pauser.register(address(pausable1));
        pauser.register(address(pausable2));

        // Clear pauser before unregistering (required validation)
        pausable1.setPauser(address(0));

        pauser.unregister(address(pausable1));

        address[] memory contracts = pauser.getPausableContracts();
        assertEq(contracts.length, 1, "Should have 1 contract after unregister");
        assertEq(contracts[0], address(pausable2), "Remaining contract should be pausable2");
    }

    function test_unregister_setsIsRegisteredFalse() public {
        pauser.register(address(pausable1));

        // Clear pauser before unregistering (required validation)
        pausable1.setPauser(address(0));

        pauser.unregister(address(pausable1));

        assertFalse(pauser.isRegistered(address(pausable1)), "isRegistered should be false");
    }

    function test_unregister_emitsContractUnregisteredEvent() public {
        pauser.register(address(pausable1));

        // Clear pauser before unregistering (required validation)
        pausable1.setPauser(address(0));

        vm.expectEmit(true, false, false, false);
        emit IPauser.ContractUnregistered(address(pausable1));

        pauser.unregister(address(pausable1));
    }

    function test_unregister_revertsIfNotOwner() public {
        pauser.register(address(pausable1));

        vm.prank(user1);
        vm.expectRevert();
        pauser.unregister(address(pausable1));
    }

    function test_unregister_revertsIfNotRegistered() public {
        vm.expectRevert();
        pauser.unregister(address(pausable1));
    }

    // ============ PAUSE TESTS ============

    function test_pause_burnsEyeTokens() public {
        pauser.register(address(pausable1));

        uint256 userBalanceBefore = eyeToken.balanceOf(user1);
        uint256 deadBalanceBefore = eyeToken.balanceOf(DEAD_ADDRESS);

        vm.prank(user1);
        pauser.pause();

        uint256 userBalanceAfter = eyeToken.balanceOf(user1);
        uint256 deadBalanceAfter = eyeToken.balanceOf(DEAD_ADDRESS);

        assertEq(userBalanceBefore - userBalanceAfter, DEFAULT_BURN_AMOUNT, "User should lose burn amount");
        assertEq(deadBalanceAfter - deadBalanceBefore, DEFAULT_BURN_AMOUNT, "Dead address should receive burn amount");
    }

    function test_pause_callsPauseOnAllRegisteredContracts() public {
        pauser.register(address(pausable1));
        pauser.register(address(pausable2));

        vm.prank(user1);
        pauser.pause();

        assertTrue(pausable1.isPaused(), "Pausable1 should be paused");
        assertTrue(pausable2.isPaused(), "Pausable2 should be paused");
        assertEq(pausable1.pauseCallCount(), 1, "Pausable1 pause should be called once");
        assertEq(pausable2.pauseCallCount(), 1, "Pausable2 pause should be called once");
    }

    function test_pause_emitsPauseTriggeredEvent() public {
        pauser.register(address(pausable1));

        vm.expectEmit(true, false, false, true);
        emit IPauser.PauseTriggered(user1, DEFAULT_BURN_AMOUNT);

        vm.prank(user1);
        pauser.pause();
    }

    function test_pause_revertsIfNoContractsRegistered() public {
        vm.prank(user1);
        vm.expectRevert();
        pauser.pause();
    }

    function test_pause_revertsIfInsufficientEyeBalance() public {
        pauser.register(address(pausable1));

        address poorUser = makeAddr("poorUser");
        eyeToken.mint(poorUser, 100 * 1e18); // Less than burn amount

        vm.prank(poorUser);
        eyeToken.approve(address(pauser), type(uint256).max);

        vm.prank(poorUser);
        vm.expectRevert();
        pauser.pause();
    }

    function test_pause_revertsIfEyeTransferFails() public {
        pauser.register(address(pausable1));

        address noApprovalUser = makeAddr("noApprovalUser");
        eyeToken.mint(noApprovalUser, 10000 * 1e18);
        // No approval given

        vm.prank(noApprovalUser);
        vm.expectRevert();
        pauser.pause();
    }

    function test_pause_worksWithMultipleContracts() public {
        pauser.register(address(pausable1));
        pauser.register(address(pausable2));
        pauser.register(address(pausable3));

        vm.prank(user1);
        pauser.pause();

        assertTrue(pausable1.isPaused(), "Pausable1 should be paused");
        assertTrue(pausable2.isPaused(), "Pausable2 should be paused");
        assertTrue(pausable3.isPaused(), "Pausable3 should be paused");
    }

    // ============ UNPAUSE TESTS ============

    function test_unpause_callsUnpauseOnAllRegisteredContracts() public {
        pauser.register(address(pausable1));
        pauser.register(address(pausable2));

        // First pause
        vm.prank(user1);
        pauser.pause();

        // Then unpause
        pauser.unpause();

        assertFalse(pausable1.isPaused(), "Pausable1 should be unpaused");
        assertFalse(pausable2.isPaused(), "Pausable2 should be unpaused");
        assertEq(pausable1.unpauseCallCount(), 1, "Pausable1 unpause should be called once");
        assertEq(pausable2.unpauseCallCount(), 1, "Pausable2 unpause should be called once");
    }

    function test_unpause_emitsUnpauseTriggeredEvent() public {
        pauser.register(address(pausable1));

        vm.prank(user1);
        pauser.pause();

        vm.expectEmit(true, false, false, false);
        emit IPauser.UnpauseTriggered(owner);

        pauser.unpause();
    }

    function test_unpause_revertsIfNotOwner() public {
        pauser.register(address(pausable1));

        vm.prank(user1);
        pauser.pause();

        vm.prank(user1);
        vm.expectRevert();
        pauser.unpause();
    }

    // ============ CONFIG TESTS ============

    function test_config_updatesEyeBurnAmount() public {
        uint256 newBurnAmount = 2000 * 1e18;
        pauser.config(newBurnAmount, address(eyeToken));

        assertEq(pauser.eyeBurnAmount(), newBurnAmount, "Burn amount should be updated");
    }

    function test_config_updatesEyeToken() public {
        MockEYE newEyeToken = new MockEYE();
        pauser.config(DEFAULT_BURN_AMOUNT, address(newEyeToken));

        assertEq(pauser.eyeToken(), address(newEyeToken), "EYE token should be updated");
    }

    function test_config_emitsConfigUpdatedEvent() public {
        uint256 newBurnAmount = 2000 * 1e18;
        MockEYE newEyeToken = new MockEYE();

        vm.expectEmit(false, false, false, true);
        emit IPauser.ConfigUpdated(newBurnAmount, address(newEyeToken));

        pauser.config(newBurnAmount, address(newEyeToken));
    }

    function test_config_revertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pauser.config(2000 * 1e18, address(eyeToken));
    }

    function test_config_revertsIfZeroAmount() public {
        vm.expectRevert();
        pauser.config(0, address(eyeToken));
    }

    function test_config_revertsIfZeroTokenAddress() public {
        vm.expectRevert();
        pauser.config(DEFAULT_BURN_AMOUNT, address(0));
    }

    // ============ PAUSER VALIDATION TESTS ============

    function test_register_revertsIfPauserNotSet() public {
        // Create a new MockPausable with pauser set to address(0)
        MockPausable noPauserContract = new MockPausable(address(0));

        vm.expectRevert("Pauser: contract has not set this contract as its pauser");
        pauser.register(address(noPauserContract));
    }

    function test_register_revertsIfPauserSetToWrongAddress() public {
        // Create a new MockPausable with pauser set to a different address
        address wrongAddress = makeAddr("wrongPauser");
        MockPausable wrongPauserContract = new MockPausable(wrongAddress);

        vm.expectRevert("Pauser: contract has not set this contract as its pauser");
        pauser.register(address(wrongPauserContract));
    }

    function test_unregister_revertsIfPauserStillSet() public {
        pauser.register(address(pausable1));

        // Try to unregister WITHOUT clearing the pauser
        vm.expectRevert("Pauser: contract still has this contract set as its pauser");
        pauser.unregister(address(pausable1));
    }

    function test_unregister_succeedsAfterPauserCleared() public {
        pauser.register(address(pausable1));

        // Clear the pauser
        pausable1.setPauser(address(0));

        // Should succeed now
        pauser.unregister(address(pausable1));
        assertFalse(pauser.isRegistered(address(pausable1)), "Should be unregistered");
    }

    function test_unregister_succeedsAfterPauserChangedToOtherAddress() public {
        pauser.register(address(pausable1));

        // Change pauser to a different address
        address otherAddress = makeAddr("otherPauser");
        pausable1.setPauser(otherAddress);

        // Should succeed because pauser is no longer this Global Pauser
        pauser.unregister(address(pausable1));
        assertFalse(pauser.isRegistered(address(pausable1)), "Should be unregistered");
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_getPausableContracts_returnsEmptyArrayInitially() public {
        address[] memory contracts = pauser.getPausableContracts();
        assertEq(contracts.length, 0, "Should return empty array initially");
    }

    function test_getPausableContracts_returnsAllRegisteredContracts() public {
        pauser.register(address(pausable1));
        pauser.register(address(pausable2));
        pauser.register(address(pausable3));

        address[] memory contracts = pauser.getPausableContracts();
        assertEq(contracts.length, 3, "Should return 3 contracts");
        assertEq(contracts[0], address(pausable1), "First should be pausable1");
        assertEq(contracts[1], address(pausable2), "Second should be pausable2");
        assertEq(contracts[2], address(pausable3), "Third should be pausable3");
    }
}
