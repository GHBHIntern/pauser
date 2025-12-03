// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPauser.sol";
import "./interfaces/IPausable.sol";
import "./interfaces/IBurnable.sol";

/**
 * @title Pauser
 * @notice Global emergency pause mechanism that can pause multiple contracts
 * @dev Allows anyone to pause registered contracts by burning EYE tokens
 *      Only owner can unpause and manage registered contracts
 */
contract Pauser is Ownable, IPauser {
    using SafeERC20 for IERC20;

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
     * @param eyeTokenAddress Address of the EYE token contract
     */
    constructor(address eyeTokenAddress) Ownable(msg.sender) {
        require(eyeTokenAddress != address(0), "Pauser: EYE token cannot be zero address");
        _eyeToken = IERC20(eyeTokenAddress);
        eyeBurnAmount = 1000 * 1e18; // Default: 1000 EYE tokens
    }

    // ============ PUBLIC FUNCTIONS ============

    /**
     * @notice Trigger a pause on all registered contracts by burning EYE tokens
     * @dev Anyone can call this function if they have enough EYE tokens
     *      Burns EYE tokens using the token's burn() function as an economic barrier
     */
    function pause() external {
        require(_pausableContracts.length > 0, "Pauser: no contracts registered");

        // Transfer EYE tokens from caller to this contract, then burn them
        _eyeToken.safeTransferFrom(msg.sender, address(this), eyeBurnAmount);
        IBurnable(address(_eyeToken)).burn(eyeBurnAmount);

        // Pause all registered contracts
        for (uint256 i = 0; i < _pausableContracts.length; i++) {
            IPausable(_pausableContracts[i]).pause();
        }

        emit PauseTriggered(msg.sender, eyeBurnAmount);
    }

    /**
     * @notice Unpause all registered contracts
     * @dev Only the owner can unpause
     *      Loops through all registered contracts and calls unpause()
     */
    function unpause() external onlyOwner {
        // Unpause all registered contracts
        for (uint256 i = 0; i < _pausableContracts.length; i++) {
            IPausable(_pausableContracts[i]).unpause();
        }

        emit UnpauseTriggered(msg.sender);
    }

    // ============ OWNER FUNCTIONS ============

    /**
     * @notice Register a pausable contract
     * @param pausableContract Address of the contract to register
     * @dev Validates that the contract has set this Global Pauser as its authorized pauser
     */
    function register(address pausableContract) external onlyOwner {
        require(pausableContract != address(0), "Pauser: cannot register zero address");
        require(!isRegistered[pausableContract], "Pauser: contract already registered");

        // Verify that the pausable contract has set this Global Pauser as its pauser
        // This ensures backward compatibility with Behodler3's address public pauser pattern
        try IPausable(pausableContract).pauser() returns (address currentPauser) {
            require(currentPauser == address(this), "Pauser: contract has not set this contract as its pauser");
        } catch {
            revert("Pauser: unable to verify pauser - contract may not implement pauser() getter");
        }

        // Add to tracking structures
        _pausableContracts.push(pausableContract);
        _contractIndex[pausableContract] = _pausableContracts.length - 1;
        isRegistered[pausableContract] = true;

        emit ContractRegistered(pausableContract);
    }

    /**
     * @notice Unregister a pausable contract
     * @param pausableContract Address of the contract to unregister
     * @dev Uses swap-and-pop pattern for O(1) removal
     *      Validates that the contract has cleared this Global Pauser from its pauser field
     */
    function unregister(address pausableContract) external onlyOwner {
        require(isRegistered[pausableContract], "Pauser: contract not registered");

        // Verify that the pausable contract has cleared this Global Pauser as its pauser
        // This ensures the contract has revoked authorization before unregistration
        try IPausable(pausableContract).pauser() returns (address currentPauser) {
            require(currentPauser != address(this), "Pauser: contract still has this contract set as its pauser");
        } catch {
            revert("Pauser: unable to verify pauser - contract may not implement pauser() getter");
        }

        // Implement swap-and-pop pattern for O(1) removal
        uint256 index = _contractIndex[pausableContract];
        uint256 lastIndex = _pausableContracts.length - 1;

        if (index != lastIndex) {
            address lastContract = _pausableContracts[lastIndex];
            _pausableContracts[index] = lastContract;
            _contractIndex[lastContract] = index;
        }

        _pausableContracts.pop();
        delete _contractIndex[pausableContract];
        isRegistered[pausableContract] = false;

        emit ContractUnregistered(pausableContract);
    }

    /**
     * @notice Configure the Pauser contract parameters
     * @param newBurnAmount New amount of EYE tokens required to pause
     * @param newTokenAddress New EYE token address
     * @dev Allows owner to update burn amount and token address with validations
     */
    function config(uint256 newBurnAmount, address newTokenAddress) external onlyOwner {
        require(newBurnAmount > 0, "Pauser: burn amount cannot be zero");
        require(newTokenAddress != address(0), "Pauser: token address cannot be zero");

        eyeBurnAmount = newBurnAmount;
        _eyeToken = IERC20(newTokenAddress);

        emit ConfigUpdated(newBurnAmount, newTokenAddress);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get all registered pausable contracts
     * @return A copy of the array of registered pausable contract addresses
     */
    function getPausableContracts() external view returns (address[] memory) {
        return _pausableContracts;
    }

    /**
     * @notice Get the EYE token address
     * @return Address of the EYE token contract
     */
    function eyeToken() external view returns (address) {
        return address(_eyeToken);
    }
}
