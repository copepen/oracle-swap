# Pyth Oracle AMM

This directory contains an example oracle AMM application using Pyth price feeds.
The oracle AMM manages a pool of two tokens(Base, Quote) and allows a user to trade with the pool at the current Pyth price. Anyone can add liquidty for swap using single token(Base or Quote) and 0.25% swap fee is introduced for incentiving liquidity providers.

This application has two components. The first component is a smart contract (in the `contract` directory) that manages the pool and implements the trading functionality.
The second is a frontend application (in the `app` directory) that communicates with the smart contract.

Please see the [Pyth documentation](https://docs.pyth.network/documentation/pythnet-price-feeds) for more information about Pyth and how to integrate it into your application.

**Warning** this AMM is intended only as a demonstration of Pyth price feeds and is **not for production use**.

## AMM Contract

All of the commands in this section expect to be run from the `contract` directory.

### Building

You need to have [Foundry](https://getfoundry.sh/) and `node` installed to run this example.
Once you have installed these tools, run the following commands from the [`contract`](./contract) directory:

```
forge install foundry-rs/forge-std@2c7cbfc6fbede6d7c9e6b17afe997e3fdfe22fef --no-git --no-commit
forge install pyth-network/pyth-sdk-solidity@v2.2.0 --no-git --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v4.8.1 --no-git --no-commit
```

### Testing

Simply run `forge test` in the [`contract`](./contract) directory. This command will run the
tests located in the [`contract/test`](./contract/test) directory.

### Deploying

To deploy `OracleSwap` contract, you first need to configure the target network and the tokens in the AMM pool.
Edit the configuration parameters in the [OracleSwap deploy script](./contract/scripts/deploy_swap.sh) and then run it using `./scripts/deploy_swap.sh`.
The code comments in that file should help you populate the parameters correctly.

If you don't have ERC-20 tokens to test with, you can use the [Token deploy script](./contract/scripts/deploy_token.sh) to create some for testing.
Edit the configuration parameters in there before running to set the network and token name.
This will deploy 2 new mock tokens(Base, Quote) and print out contract addresses.

When `OracleSwap` contract is deployed, you need to deploy `OracleSwapPair` contract using [OracleSwapPair deploy script](./contract/scripts/deploy_swapPair.sh).

### Create ABI

If you change the contract, you will need to create a new ABI.
The frontend uses this ABI to create transactions.
You can overwrite the existing ABI by running the following command:

```
forge compile
```

## Frontend Application

By default, the frontend is configured to use the already deployed version of the oracle AMM
at address [`0xf50e5b2b1037f9ab7b4f4efe3dbed5f0caa343bc`](https://mumbai.polygonscan.com/address/0xf50e5b2b1037f9ab7b4f4efe3dbed5f0caa343bc) on Polygon Mumbai.
This means you can start playing with the application without going through the steps above (Remember to switch your wallet to Mumbai and to claim funds from a faucet to pay for the gas).

### Run

After building, you can start the frontend by navigating to the `app/` directory and running:

`npm run start`

Then navigate your browser to `localhost:3000`.
