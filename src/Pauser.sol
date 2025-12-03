// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPauser.sol";
import "./interfaces/IPausable.sol";

/**
 * @title Pauser
 * @notice Global emergency pause mechanism that can pause multiple contracts
 * @dev Allows anyone to pause registered contracts by burning EYE tokens
 *      Only owner can unpause and manage registered contracts
 */
contract Pauser is Ownable, IPauser {
    // ============ STATE VARIABLES ============

    /// @notice The EYE token used for burn mechanism
    IERC20 internal _eyeToken;

    /// @notice Amount of EYE tokens required to trigger pause
    uint256 public eyeBurnAmount;

    /// @notice Array of registered pausable contract addresses
    address[] internal _pausableContracts;

    /// @notice Mapping for O(1) registration status lookup
    mapping(address => bool) public isRegistered;

    /// @notice Mapping for efficient removal from array (swap-and-pop pattern)
    mapping(address => uint256) internal _contractIndex;

    // ============ CONSTRUCTOR ============

    /**
     * @notice Create a new Global Pauser
     * @param _eyeToken Address of the EYE token contract
     */
    constructor(address _eyeToken) Ownable(msg.sender) {
        // Stub constructor - will revert in tests
    }

    // ============ PUBLIC FUNCTIONS ============

    /**
     * @notice Trigger a pause on all registered contracts by burning EYE tokens
     * @dev Anyone can call this function if they have enough EYE tokens
     */
    function pause() external {
        // Stub - will revert in tests
    }

    /**
     * @notice Unpause all registered contracts
     * @dev Only the owner can unpause
     */
    function unpause() external onlyOwner {
        // Stub - will revert in tests
    }

    // ============ OWNER FUNCTIONS ============

    /**
     * @notice Register a pausable contract
     * @param pausableContract Address of the contract to register
     */
    function register(address pausableContract) external onlyOwner {
        // Stub - will revert in tests
        //TODO: for green phase, check if pausableContract has already set this contract as its pauser. Revert with helpful message if not
    }

    /**
     * @notice Unregister a pausable contract
     * @param pausableContract Address of the contract to unregister
     */
    function unregister(address pausableContract) external onlyOwner {
        // Stub - will revert in tests
          //TODO: for green phase, check if pausableContract has already unset this contract as its pauser. Revert with helpful message if not
    }

    /**
     * @notice Configure the Pauser contract parameters
     * @param _eyeBurnAmount New amount of EYE tokens required to pause
     * @param _eyeToken New EYE token address
     */
    function config(uint256 _eyeBurnAmount, address _eyeToken) external onlyOwner {
        // Stub - will revert in tests
        //TODO: let the burn amount default to 1000 but be configurable as is show here
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get all registered pausable contracts
     * @return Array of pausable contract addresses
     */
    function getPausableContracts() external view returns (address[] memory) {
        return new address[](0); // Return empty array (stub)
    }

    /**
     * @notice Get the EYE token address
     * @return Address of the EYE token contract
     */
    function eyeToken() external view returns (address) {
        return address(_eyeToken);
    }
}
