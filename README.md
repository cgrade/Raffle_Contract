# Raffle Smart Contract

## Overview

**Raffle** is a decentralized application that allows users to participate in a raffle and randomly selects a winner. The contract utilizes Chainlink VRF (Verifiable Random Function) for secure random number generation, ensuring fairness in the selection process.

## Features

- Users can enter the raffle by sending ETH.
- A winner is randomly selected after a specified time interval.
- The contract emits events for significant actions, such as entering the raffle and selecting a winner.
- Implements Chainlink VRF for secure and verifiable randomness.

## Smart Contracts

### 1. Raffle.sol

- **Description**: The main contract that manages the raffle process.
- **Key Functions**:
  - `enterRaffle()`: Allows users to enter the raffle by sending ETH.
  - `checkUpkeep()`: Checks if the conditions are met to pick a winner.
  - `performUpkeep()`: Performs the upkeep to select a winner.
  - `fulfillRandomWords()`: Callback function called by Chainlink VRF to fulfill the random number request.
  - `getEntranceFee()`: Returns the entrance fee for the raffle.
  - `getRaffleState()`: Returns the current state of the raffle.
  - `getPlayer(uint256 index)`: Returns the address of a player at a specific index.

### 2. DeployRaffle.s.sol

- **Description**: A script for deploying the Raffle contract.
- **Key Functions**:
  - `run()`: Deploys the Raffle contract and sets up the necessary configurations.

### 3. HelperConfig.s.sol

- **Description**: A helper contract that manages network configurations and settings.
- **Key Functions**:
  - `getConfig()`: Returns the configuration for the current network.
  - `setConfig()`: Sets the configuration for a specific network.

### 4. LinkToken.sol

- **Description**: A mock ERC20 token contract for LINK, used in the raffle.
- **Key Functions**:
  - `mint()`: Mints new tokens to a specified address.
  - `transferAndCall()`: Transfers tokens to a contract address and calls a function on the recipient.

### 5. RaffleTest.t.sol

- **Description**: Unit tests for the Raffle contract.
- **Key Tests**:
  - Tests for entering the raffle, checking upkeep, performing upkeep, and fulfilling random words.

## Installation

To install the necessary dependencies, run:

```shell
$ forge install
```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Deploy

To deploy the contracts, use the following command:

```shell
$ forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Contributing

If you would like to contribute to this project, please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
