// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "contracts/TestErc20.sol";
import {OracleSwapPair} from "contracts/OracleSwapPair.sol";
import {OracleSwap} from "contracts/OracleSwap.sol";

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract Deploy is Script {
    function _deployMyToken(string memory name, string memory symbol) internal {
        vm.startBroadcast();
        new MyToken(name, symbol);
        vm.stopBroadcast();
    }

    function _deployOralceSwap(
        address pyth,
        bytes32 baseTokenPriceId,
        bytes32 quoteTokenPriceId,
        address baseToken,
        address quoteToken
    ) internal {
        vm.startBroadcast();
        new OracleSwap(
            pyth,
            baseTokenPriceId,
            quoteTokenPriceId,
            baseToken,
            quoteToken
        );
        vm.stopBroadcast();
    }

    function _deployOralceSwapPair(
        address baseToken,
        address quoteToken,
        address oracleSwap
    ) internal {
        vm.startBroadcast();
        new OracleSwapPair(baseToken, quoteToken, oracleSwap);
        vm.stopBroadcast();
    }
}

contract DeployTokens is Deploy {
    function run() external {
        // deploy Tokens
        _deployMyToken("Base token", "BST");
        _deployMyToken("Quote token", "QUT");
    }
}

contract DeploySwap is Deploy {
    function run() external {
        address pyth = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
        bytes32 baseTokenPriceId = 0x08f781a893bc9340140c5f89c8a96f438bcfae4d1474cc0f688e3a52892c7318;
        bytes32 quoteTokenPriceId = 0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588;
        address baseToken = 0x6114446F40b1470095C999865a1a8bF98C649c56;
        address quoteToken = 0x4dF5E254b96A9F4CaCB1eb5eE843931A1a9e191b;

        // deploy OracleSwap contract
        _deployOralceSwap(
            pyth,
            baseTokenPriceId,
            quoteTokenPriceId,
            baseToken,
            quoteToken
        );
    }
}

contract DeploySwapPair is Deploy {
    function run() external {
        address baseToken = 0x6114446F40b1470095C999865a1a8bF98C649c56;
        address quoteToken = 0x4dF5E254b96A9F4CaCB1eb5eE843931A1a9e191b;
        address oracleSwap = 0xF50e5b2b1037f9Ab7B4f4EfE3dBeD5f0CAa343Bc;

        // deploy OracleSwapPair contract
        _deployOralceSwapPair(baseToken, quoteToken, oracleSwap);
    }
}
