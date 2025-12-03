// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IPausable.sol";

/**
 * @title MockPausable
 * @notice Mock pausable contract for testing the Global Pauser
 * @dev Tracks pause state and call history for verification in tests
 */
contract MockPausable is IPausable {
    // ============ STATE VARIABLES ============

    /// @notice Whether this contract is currently paused
    bool public isPaused;

    /// @notice Number of times pause() has been called
    uint256 public pauseCallCount;

    /// @notice Number of times unpause() has been called
    uint256 public unpauseCallCount;

    /// @notice Last address that called pause()
    address public lastPauseCaller;

    /// @notice Last address that called unpause()
    address public lastUnpauseCaller;

    /// @notice The authorized pauser address (only this address can pause/unpause)
    /// @dev This exposes a .pauser() getter for backward compatibility with Behodler3
    address public pauser;

    // ============ CONSTRUCTOR ============

    constructor(address _pauser) {
        pauser = _pauser;
    }

    // ============ PAUSABLE INTERFACE ============

    /**
     * @notice Pause this contract
     * @dev Reverts if caller is not the authorized pauser
     */
    function pause() external {
        require(msg.sender == pauser, "MockPausable: caller is not authorized pauser");
        isPaused = true;
        pauseCallCount++;
        lastPauseCaller = msg.sender;
    }

    /**
     * @notice Unpause this contract
     * @dev Reverts if caller is not the authorized pauser
     */
    function unpause() external {
        require(msg.sender == pauser, "MockPausable: caller is not authorized pauser");
        isPaused = false;
        unpauseCallCount++;
        lastUnpauseCaller = msg.sender;
    }

    // ============ TEST HELPERS ============

    /**
     * @notice Update the authorized pauser
     * @param _pauser New authorized pauser address
     */
    function setPauser(address _pauser) external {
        pauser = _pauser;
    }

    /**
     * @notice Reset call counters (useful for test isolation)
     */
    function resetCounters() external {
        pauseCallCount = 0;
        unpauseCallCount = 0;
        lastPauseCaller = address(0);
        lastUnpauseCaller = address(0);
    }
}
