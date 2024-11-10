// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

/**
 * @title CreateSubscription
 * @dev This contract handles the creation of a VRF subscription.
 */
contract CreateSubscription is Script {
    /**
     * @notice Creates a subscription using configuration from HelperConfig.
     * @return subId The ID of the created subscription.
     * @return vrfCoordinatorV2_5 The address of the VRF Coordinator.
     */
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV2_5, account);
    }

    /**
     * @notice Creates a VRF subscription.
     * @param vrfCoordinatorV2_5 The address of the VRF Coordinator.
     * @param account The account to start broadcasting from.
     * @return subId The ID of the created subscription.
     * @return vrfCoordinatorV2_5 The address of the VRF Coordinator.
     */
    function createSubscription(address vrfCoordinatorV2_5, address account) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorV2_5);
    }

    /**
     * @notice Runs the subscription creation process.
     * @return subId The ID of the created subscription.
     * @return vrfCoordinatorV2_5 The address of the VRF Coordinator.
     */
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

/**
 * @title AddConsumer
 * @dev This contract allows adding a consumer to a VRF subscription.
 */
contract AddConsumer is Script {
    /**
     * @notice Adds a consumer contract to a VRF subscription.
     * @param contractToAddToVrf The address of the consumer contract.
     * @param vrfCoordinator The address of the VRF Coordinator.
     * @param subId The ID of the subscription.
     * @param account The account to start broadcasting from.
     */
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    /**
     * @notice Adds a consumer using configuration from HelperConfig.
     * @param mostRecentlyDeployed The address of the most recently deployed contract.
     */
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    /**
     * @notice Runs the process of adding a consumer to a subscription.
     */
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

/**
 * @title FundSubscription
 * @dev This contract handles funding a VRF subscription.
 */
contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    /**
     * @notice Funds a subscription using configuration from HelperConfig.
     */
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV2_5);
        }

        fundSubscription(vrfCoordinatorV2_5, subId, link, account);
    }

    /**
     * @notice Funds a VRF subscription.
     * @param vrfCoordinatorV2_5 The address of the VRF Coordinator.
     * @param subId The ID of the subscription.
     * @param link The address of the LINK token.
     * @param account The account to start broadcasting from.
     */
    function fundSubscription(address vrfCoordinatorV2_5, uint256 subId, address link, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    /**
     * @notice Runs the funding process for a subscription.
     */
    function run() external {
        fundSubscriptionUsingConfig();
    }
}