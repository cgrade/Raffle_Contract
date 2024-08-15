// Layout of Contract:
/**
 * Versions
 * Imports
 * Errors
 * Interfaces, libraries, contracts
 * Type declarations
 * State Variables
 * Events
 * Modifiers
 * Functions
 */

// Layout of Functions
/**
 * constructor
 * receive function (if exist)
 * fallback function (if exist)
 * external
 * private
 * view & pure functions
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Abraham Elijah (Mr. Grade)
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*------------------------ Errors -------------------------------*/
    error Raffle__SendMoreToEnterRafle();
    error Raffle__TransferFailed();
    error Raffle__StateNotOpened();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /*------------------------- Type delcarations ---------------------*/
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* ------------------------ State Variables -----------------------*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // @dev the duration for the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_subsrciptionId;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyHash;
    address private immutable i_linkToken;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*------------------------- Events -------------------------------*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId );

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

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough Eth sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRafle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__StateNotOpened();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // when should winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked
     *
     * the following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Iimplicitly, your subscription has LINK
     * @param  - parameters not required
     * @return upkeepNeeded - true if it's time to restart the lottery.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        // check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

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
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256, /*requestId */ uint256[] calldata randomWords) internal override {
        // Checks
        // Effect (Internal Contract Size)
        uint256 indexofWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexofWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // Getter Functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
