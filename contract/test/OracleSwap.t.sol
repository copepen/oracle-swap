// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "pyth-sdk-solidity/MockPyth.sol";
import "openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";
import {OracleSwap} from "contracts/OracleSwap.sol";
import {OracleSwapPair} from "contracts/OracleSwapPair.sol";

contract OracleSwapTest is Test {
    bytes32 constant BASE_PRICE_ID =
        0x000000000000000000000000000000000000000000000000000000000000abcd;
    bytes32 constant QUOTE_PRICE_ID =
        0x0000000000000000000000000000000000000000000000000000000000001234;

    address payable constant BASE_TOKEN_MINT =
        payable(0x0000000000000000000000000000000000000011);

    address payable constant QUOTE_TOKEN_MINT =
        payable(0x0000000000000000000000000000000000000022);

    address payable constant alice =
        payable(0x0000000000000000000000000000000000011111);
    address payable constant bob =
        payable(0x0000000000000000000000000000000000022222);
    address payable constant owner =
        payable(0x0000000000000000000000000000000000033333);

    uint256 MAX_INT = 2 ** 256 - 1;

    MockPyth public mockPyth;
    OracleSwap public swap;
    ERC20Mock baseToken;
    ERC20Mock quoteToken;
    OracleSwapPair lpToken;

    function setUp() public {
        // Change the address to the owner
        vm.startPrank(owner);

        // Charge ETH to accounts
        vm.deal(alice, 1000e18);
        vm.deal(bob, 1000e18);
        vm.deal(owner, 1000e18);

        // Creating a mock of Pyth contract with 60 seconds validTimePeriod (for staleness)
        // and 1 wei fee for updating the price.
        mockPyth = new MockPyth(60, 1);

        // Create baseToken and quoteToken contract instance
        baseToken = new ERC20Mock(
            "Base token",
            "BST",
            BASE_TOKEN_MINT,
            100000 * 10 ** 18
        );
        quoteToken = new ERC20Mock(
            "Qoute token",
            "QUT",
            QUOTE_TOKEN_MINT,
            100000 * 10 ** 18
        );

        // Create OracleSwap contract instance
        swap = new OracleSwap(
            address(mockPyth),
            BASE_PRICE_ID,
            QUOTE_PRICE_ID,
            address(baseToken),
            address(quoteToken)
        );

        // Create OracleSwapPair contract instance
        lpToken = new OracleSwapPair(
            address(baseToken),
            address(quoteToken),
            address(swap)
        );

        // Setup config and initialize
        swap.setLpToken(address(lpToken));

        // Mint tokens to accounts
        mintTokens(alice, 1000e18, 1000e18);
        mintTokens(bob, 1000e18, 1000e18);
        mintTokens(owner, 1000e18, 1000e18);

        baseToken.approve(address(swap), MAX_INT);
        quoteToken.approve(address(swap), MAX_INT);

        // Add liquidity
        addLiquidity(owner, 10, 1, address(baseToken), 100e18);
        addLiquidity(owner, 10, 1, address(quoteToken), 200e18);
    }

    // Mint tokens to user
    function mintTokens(
        address user,
        uint senderBaseQty,
        uint senderQuoteQty
    ) private {
        baseToken.mint(user, senderBaseQty);
        quoteToken.mint(user, senderQuoteQty);
    }

    // Add liquidity with single token
    function addLiquidity(
        address user,
        int32 basePrice,
        int32 quotePrice,
        address tokenIn,
        uint256 tokenAmount
    ) private {
        vm.stopPrank();
        vm.startPrank(user);

        bytes[] memory updateData = new bytes[](2);

        // This is a dummy update data for Eth. It shows the price as $1000 +- $10 (with -5 exponent).
        updateData[0] = mockPyth.createPriceFeedUpdateData(
            BASE_PRICE_ID,
            basePrice * 100000,
            10 * 100000,
            -5,
            basePrice * 100000,
            10 * 100000,
            uint64(block.timestamp)
        );
        updateData[1] = mockPyth.createPriceFeedUpdateData(
            QUOTE_PRICE_ID,
            quotePrice * 100000,
            10 * 100000,
            -5,
            quotePrice * 100000,
            10 * 100000,
            uint64(block.timestamp)
        );

        uint value = mockPyth.getUpdateFee(updateData);
        swap.addLiquidity{value: value}(tokenIn, tokenAmount, updateData);
    }

    // Swap tokens between baseToken and quoteToken
    function doSwap(
        int32 basePrice,
        int32 quotePrice,
        bool isBuy,
        uint size
    ) private {
        bytes[] memory updateData = new bytes[](2);

        // This is a dummy update data for Eth. It shows the price as $1000 +- $10 (with -5 exponent).
        updateData[0] = mockPyth.createPriceFeedUpdateData(
            BASE_PRICE_ID,
            basePrice * 100000,
            10 * 100000,
            -5,
            basePrice * 100000,
            10 * 100000,
            uint64(block.timestamp)
        );
        updateData[1] = mockPyth.createPriceFeedUpdateData(
            QUOTE_PRICE_ID,
            quotePrice * 100000,
            10 * 100000,
            -5,
            quotePrice * 100000,
            10 * 100000,
            uint64(block.timestamp)
        );

        // Make sure the contract has enough funds to update the pyth feeds
        uint value = mockPyth.getUpdateFee(updateData);
        vm.deal(address(this), value);

        swap.swap{value: value}(isBuy, size, updateData);
    }

    function test_Swap() public {
        int32 basePrice = 10;
        int32 quotePrice = 1;
        bool isBuy = true;
        uint256 baseTokenAmount = 10e18;
        uint256 swapFee = swap.BASE_SWAP_FEE();

        // Before swap
        uint256 aliceBaseTokenBalaceBefore = baseToken.balanceOf(alice);
        uint256 aliceQuoteTokenBalaceBefore = quoteToken.balanceOf(alice);
        uint256 quoteTokenBalanceInPairBefore = quoteToken.balanceOf(
            address(lpToken)
        );

        console.log("=== Swap before ===");
        console.log("Alice: base", aliceBaseTokenBalaceBefore);
        console.log("Alice: quote", aliceQuoteTokenBalaceBefore);
        console.log("LP: quote", quoteTokenBalanceInPairBefore);

        // Do swap
        vm.stopPrank();
        vm.startPrank(alice);
        quoteToken.approve(address(swap), type(uint256).max);
        doSwap(basePrice, quotePrice, isBuy, baseTokenAmount);

        // After swap
        uint256 aliceBaseTokenBalaceAfter = baseToken.balanceOf(alice);
        uint256 aliceQuoteTokenBalaceAfter = quoteToken.balanceOf(alice);
        uint256 quoteTokenBalanceInPairAfter = quoteToken.balanceOf(
            address(lpToken)
        );

        console.log("=== Swap after ===");
        console.log("Alice: base", aliceBaseTokenBalaceAfter);
        console.log("Alice: quote", aliceQuoteTokenBalaceAfter);
        console.log("LP: quote", quoteTokenBalanceInPairAfter);

        uint256 expectedBaseAmountIn = baseTokenAmount;
        uint256 expectedQuoteAmountOut = (baseTokenAmount *
            uint256(uint32(basePrice / quotePrice)) *
            (10000 + swapFee)) /
            10000 +
            1;

        assertEq(
            aliceBaseTokenBalaceAfter - aliceBaseTokenBalaceBefore,
            expectedBaseAmountIn
        );

        assertEq(
            aliceQuoteTokenBalaceBefore - aliceQuoteTokenBalaceAfter,
            expectedQuoteAmountOut
        );

        assertEq(
            quoteTokenBalanceInPairAfter - quoteTokenBalanceInPairBefore,
            expectedQuoteAmountOut
        );
    }

    receive() external payable {}
}
