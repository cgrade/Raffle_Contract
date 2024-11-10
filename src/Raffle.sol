/**
 * @title Raffle Contract
 * @author Abraham Elijah (Mr. Grade)
 * @notice This contract allows users to participate in a raffle and randomly selects a winner.
 * @dev Implements Chainlink VRF v2.5 for secure random number generation.
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*------------------------ Errors -------------------------------*/
    error Raffle__SendMoreToEnterRafle(); // Error thrown when insufficient ETH is sent to enter the raffle
    error Raffle__TransferFailed(); // Error thrown when the transfer to the winner fails
    error Raffle__StateNotOpened(); // Error thrown when trying to enter a raffle that is not open
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState); // Error thrown when upkeep is not needed

    /*------------------------- Type declarations ---------------------*/
    enum RaffleState {
        OPEN, // Indicates the raffle is open for entries
        CALCULATING // Indicates the raffle is in the process of selecting a winner
    }

    /* ------------------------ State Variables -----------------------*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // Number of confirmations for the VRF request
    uint32 private constant NUM_WORDS = 1; // Number of random words to request

    // @dev the duration for the lottery in seconds
    uint256 private immutable i_interval; // Time interval for the raffle
    uint256 private immutable i_entranceFee; // Fee to enter the raffle
    uint256 private immutable i_subsrciptionId; // Subscription ID for Chainlink VRF
    uint32 private immutable i_callbackGasLimit; // Gas limit for the callback function
    bytes32 private immutable i_keyHash; // Key hash for the VRF
    address private immutable i_linkToken; // Address of the LINK token
    address payable[] private s_players; // Array of players who entered the raffle
    uint256 private s_lastTimeStamp; // Last timestamp when the raffle was entered
    address private s_recentWinner; // Address of the most recent winner
    RaffleState private s_raffleState; // Current state of the raffle

    /*------------------------- Events -------------------------------*/
    event RaffleEntered(address indexed player); // Event emitted when a player enters the raffle
    event WinnerPicked(address indexed winner); // Event emitted when a winner is picked
    event RequestedRaffleWinner(uint256 indexed requestId); // Event emitted when a request for a winner is made

    /**
     * @dev Constructor to initialize the raffle contract
     * @param _entranceFee The fee required to enter the raffle
     * @param interval The time interval for the raffle
     * @param vrfCoordinator The address of the VRF coordinator
     * @param gasLane The key hash for the VRF
     * @param subsrciptionId The subscription ID for Chainlink VRF
     * @param callbackGasLimit The gas limit for the callback function
     * @param linkToken The address of the LINK token
     */
    constructor(
        uint256 _entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subsrciptionId,
        uint32 callbackGasLimit,
        address linkToken
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        i_entranceFee = _entranceFee;
        i_keyHash = gasLane;
        i_subsrciptionId = subsrciptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_linkToken = linkToken;

        s_lastTimeStamp = block.timestamp; // Initialize last timestamp
        s_raffleState = RaffleState.OPEN; // Set initial state to OPEN
    }

    /**
     * @dev Allows users to enter the raffle by sending ETH
     * @notice The function checks if the user has sent enough ETH and if the raffle is open
     */
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough Eth sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRafle(); // Revert if not enough ETH sent
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__StateNotOpened(); // Revert if the raffle is not open
        }
        s_players.push(payable(msg.sender)); // Add player to the list
        emit RaffleEntered(msg.sender); // Emit event for entering the raffle
    }

    /**
     * @dev Checks if the conditions are met to pick a winner
     * @param checkData Additional data for checking upkeep (not used)
     * @return upkeepNeeded True if upkeep is needed, false otherwise
     * @return performData Data to perform upkeep (not used)
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; // Check if time interval has passed
        bool isOpen = s_raffleState == RaffleState.OPEN; // Check if the raffle is open
        bool hasBalance = address(this).balance > 0; // Check if the contract has ETH
        bool hasPlayers = s_players.length > 0; // Check if there are players

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers; // Determine if upkeep is needed
        return (upkeepNeeded, hex""); // Return upkeep status and perform data
    }

    /**
     * @dev Performs the upkeep to select a winner
     * @param performData Data for performing upkeep (not used)
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        // check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep(""); // Check if upkeep is needed
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState)); // Revert if upkeep is not needed
        }
        s_raffleState = RaffleState.CALCULATING; // Set state to CALCULATING

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subsrciptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true})) // new parameter
            })
        );
        emit RequestedRaffleWinner(requestId); // Emit event for winner request
    }

    /**
     * @dev Callback function that is called by Chainlink VRF to fulfill the random number request
     * @param requestId The ID of the request
     * @param randomWords The array of random words returned
     */
    function fulfillRandomWords(uint256, /*requestId */ uint256[] calldata randomWords) internal override {
        // Checks
        // Effect (Internal Contract Size)
        uint256 indexofWinner = randomWords[0] % s_players.length; // Determine the index of the winner
        address payable recentWinner = s_players[indexofWinner]; // Get the winner's address
        s_recentWinner = recentWinner; // Set the recent winner
        s_raffleState = RaffleState.OPEN; // Reset state to OPEN
        s_players = new address payable[](0); // Reset players array
        s_lastTimeStamp = block.timestamp; // Update last timestamp
        emit WinnerPicked(s_recentWinner); // Emit event for the winner

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}(""); // Transfer the balance to the winner
        if (!success) {
            revert Raffle__TransferFailed(); // Revert if transfer fails
        }
    }

    // Getter Functions
    /**
     * @dev Returns the entrance fee for the raffle
     * @return The entrance fee in wei
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee; // Return entrance fee
    }

    /**
     * @dev Returns the current state of the raffle
     * @return The current state of the raffle
     */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState; // Return raffle state
    }

    /**
     * @dev Returns the address of a player at a specific index
     * @param indexOfPlayer The index of the player
     * @return The address of the player
     */
    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer]; // Return player's address
    }
}
