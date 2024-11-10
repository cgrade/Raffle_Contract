// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

/**
 * @title RaffleTest
 * @dev This contract contains tests for the Raffle contract, ensuring that
 *      the raffle functionality works as intended, including entering the raffle,
 *      fulfilling random words, and picking a winner.
 */
contract RaffleTest is StdCheats, Test {
    /* Errors */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle; // Instance of the Raffle contract
    HelperConfig public helperConfig; // Instance of the HelperConfig contract

    uint256 subscriptionId; // Subscription ID for VRF
    bytes32 gasLane; // Gas lane for VRF
    uint256 automationUpdateInterval; // Interval for automation updates
    uint256 raffleEntranceFee; // Fee to enter the raffle
    uint32 callbackGasLimit; // Gas limit for callback
    address vrfCoordinatorV2_5; // Address of the VRF Coordinator

    address public PLAYER = makeAddr("player"); // Address of the player
    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Starting balance for the player

    /**
     * @dev Sets up the test environment by deploying the Raffle contract and
     *      configuring the necessary parameters.
     */
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    modifier raffleEntered() {
        // Simulates a player entering the raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier onlyOnDeployedContracts() {
        // Ensures that the tests are only run on deployed contracts
        if (block.chainid == 31337) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    /**
     * @dev Tests that fulfillRandomWords can only be called after performUpkeep.
     *      It checks for reverts when trying to fulfill nonexistent requests.
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEntered onlyOnDeployedContracts {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(raffle));

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(raffle));
    }

    /**
     * @dev Tests that fulfillRandomWords picks a winner, resets the raffle,
     *      and sends the prize money to the winner.
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered onlyOnDeployedContracts {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}