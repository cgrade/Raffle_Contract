// SPDX-License-Identifier: MIT
// @dev This contract has been adapted to fit with foundry
pragma solidity ^0.8.0;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @title ERC677 Token Interface
/// @dev Interface for contracts that can receive ERC677 tokens
interface ERC677Receiver {
    /// @notice Called when tokens are transferred to a contract
    /// @param _sender The address of the sender
    /// @param _value The amount of tokens transferred
    /// @param _data Additional data sent with the transfer
    function onTokenTransfer(address _sender, uint256 _value, bytes memory _data) external;
}

/// @title LinkToken
/// @dev A token contract that extends ERC20 with additional functionality for transferring tokens to contracts
contract LinkToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1000000000000000000000000; // Initial supply of tokens
    uint8 constant DECIMALS = 18; // Number of decimals for the token

    /// @dev Constructor that mints the initial supply to the deployer
    constructor() ERC20("LinkToken", "LINK", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Mints new tokens to a specified address
    /// @param to The address to mint tokens to
    /// @param value The amount of tokens to mint
    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    event Transfer(address indexed from, address indexed to, uint256 value, bytes data); // Event emitted on token transfer

    /**
     * @notice Transfers tokens to a contract address and calls a function on the recipient
     * @param _to The address to transfer to
     * @param _value The amount to be transferred
     * @param _data Additional data to be passed to the receiving contract
     * @return success Indicates if the transfer was successful
     */
    function transferAndCall(address _to, uint256 _value, bytes memory _data) public virtual returns (bool success) {
        super.transfer(_to, _value); // Call the transfer function from ERC20
        emit Transfer(msg.sender, _to, _value, _data); // Emit the transfer event
        if (isContract(_to)) {
            contractFallback(_to, _value, _data); // Call the fallback function if the recipient is a contract
        }
        return true;
    }

    // PRIVATE

    /// @dev Calls the onTokenTransfer function on the recipient contract
    /// @param _to The address of the recipient contract
    /// @param _value The amount of tokens transferred
    /// @param _data Additional data sent with the transfer
    function contractFallback(address _to, uint256 _value, bytes memory _data) private {
        ERC677Receiver receiver = ERC677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data); // Notify the recipient contract
    }

    /// @dev Checks if an address is a contract
    /// @param _addr The address to check
    /// @return hasCode True if the address has code, false otherwise
    function isContract(address _addr) private view returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr) // Get the size of the code at the address
        }
        return length > 0; // Return true if the length is greater than 0
    }
}

