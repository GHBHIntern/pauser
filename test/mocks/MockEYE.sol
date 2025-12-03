// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockEYE
 * @notice Mock ERC20 token for testing the Pauser contract
 */
contract MockEYE is ERC20 {
    constructor() ERC20("Mock EYE", "EYE") {
        // Mint 1 million EYE tokens to deployer for testing
        _mint(msg.sender, 1_000_000 * 1e18);
    }

    /**
     * @notice Mint tokens to an address (for testing purposes)
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
