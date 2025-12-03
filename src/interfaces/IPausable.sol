// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPausable
 * @notice Interface that pausable contracts must implement to be compatible with the Global Pauser
 * @dev Contracts implementing this interface can be registered with the Global Pauser
 *      and will be paused/unpaused when the Global Pauser is triggered
 *
 *      Implementation requirements:
 *      - pause() should revert if caller is not the authorized pauser
 *      - unpause() should revert if caller is not the authorized pauser
 *      - Contracts should maintain internal state to track pause status
 */
interface IPausable {
    /**
     * @notice Pause the contract
     * @dev Should revert if caller is not the authorized pauser
     *      Should set internal pause state to prevent operations while paused
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     * @dev Should revert if caller is not the authorized pauser
     *      Should clear internal pause state to resume normal operations
     */
    function unpause() external;
}
