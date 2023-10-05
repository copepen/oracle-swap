// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "pyth-sdk-solidity/IPyth.sol";
import "pyth-sdk-solidity/PythStructs.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "interfaces/IOracleSwapPair.sol";

// Example oracle AMM powered by Pyth price feeds.
//
// The contract holds a pool of two ERC-20 tokens, the BASE and the QUOTE, and allows users to swap tokens
// for the pair BASE/QUOTE. For example, the base could be WETH and the quote could be USDC, in which case you can
// buy WETH for USDC and vice versa. The pool offers to swap between the tokens at the current Pyth exchange rate for
// BASE/QUOTE, which is computed from the BASE/USD price feed and the QUOTE/USD price feed.
//
// This contract only implements the swap functionality. It does not implement any pool balancing logic (e.g., skewing the
// price to reflect an unbalanced pool) or depositing / withdrawing funds. When deployed, the contract needs to be sent
// some quantity of both the base and quote token in order to function properly (using the ERC20 transfer function to
// the contract's address).
contract OracleSwap is Ownable {
    IPyth _pyth;

    bytes32 _baseTokenPriceId;
    bytes32 _quoteTokenPriceId;

    address public baseToken;
    address public quoteToken;
    address public lpToken;

    // swap fees
    uint256 public constant BASE_SWAP_FEE = 25; // 0.25%
    uint256 public constant MAX_SWAP_FEE = 85; // 0.85%

    event Swap(
        address indexed sender,
        uint tokenIn,
        uint tokenOut,
        uint amounIn,
        uint amountOut
    );

    event AddLiquidity(
        address indexed user,
        address tokenIn,
        uint amountIn,
        uint timestamp
    );

    event RemoveLiquidity(
        address indexed user,
        address tokenOut,
        uint amountOut,
        uint timestamp
    );

    event LpTokenUpdated(address indexed user, address lpToken, uint timestamp);

    constructor(
        address pyth_,
        bytes32 baseTokenPriceId_,
        bytes32 quoteTokenPriceId_,
        address baseToken_,
        address quoteToken_
    ) {
        _pyth = IPyth(pyth_);
        _baseTokenPriceId = baseTokenPriceId_;
        _quoteTokenPriceId = quoteTokenPriceId_;
        baseToken = baseToken_;
        quoteToken = quoteToken_;
    }

    /**
     * @dev Throws if OracleSwapPair address is not set
     */
    modifier nonZeroOracleSwapPair() {
        require(lpToken != address(0), "OS: zero LP address");

        _;
    }

    // Buy or sell a quantity of the base token. `size` represents the quantity of the base token with the same number
    // of decimals as expected by its ERC-20 implementation. If `isBuy` is true, the contract will send the caller
    // `size` base tokens; if false, `size` base tokens will be transferred from the caller to the contract. Some
    // number of quote tokens will be transferred in the opposite direction; the exact number will be determined by
    // the current _pyth price. The transaction will fail if either the pool or the sender does not have enough of the
    // requisite tokens for these transfers.
    //
    // `pythUpdateData` is the binary _pyth price update data (retrieved from Pyth's price
    // service); this data should contain a price update for both the base and quote price feeds.
    // See the frontend code for an example of how to retrieve this data and pass it to this function.
    function swap(
        bool isBuy,
        uint size,
        bytes[] calldata pythUpdateData
    ) external payable nonZeroOracleSwapPair {
        (uint256 basePrice, uint256 quotePrice) = _getPrices(pythUpdateData);

        if (isBuy) {
            uint256 quoteSize = (((size * basePrice) *
                (10000 + BASE_SWAP_FEE)) / 10000) / quotePrice;

            quoteSize += 1;
            IERC20(quoteToken).transferFrom(msg.sender, lpToken, quoteSize);
            IERC20(baseToken).transferFrom(address(lpToken), msg.sender, size);
        } else {
            uint256 quoteSize = (((size * basePrice) *
                (10000 - BASE_SWAP_FEE)) / 10000) / quotePrice;
            quoteSize += 1;

            IERC20(baseToken).transferFrom(msg.sender, address(this), size);
            IERC20(quoteToken).transferFrom(
                address(lpToken),
                msg.sender,
                quoteSize
            );
        }
    }

    // Add liquidty
    function addLiquidity(
        address inTokenAddress,
        uint256 inTokenAmount,
        bytes[] calldata pythUpdateData
    ) external payable nonZeroOracleSwapPair {
        (uint256 basePrice, uint256 quotePrice) = _getPrices(pythUpdateData);

        uint256 lpTotalSupply = IOracleSwapPair(lpToken).totalSupply();
        uint256 lpPrice = 1e18;

        if (lpTotalSupply > 0) {
            uint256 baseAmount = IOracleSwapPair(lpToken).baseBalance();
            uint256 quoteAmount = IOracleSwapPair(lpToken).quoteBalance();
            lpPrice =
                (basePrice * baseAmount + quotePrice * quoteAmount) /
                lpTotalSupply;
        }

        bool isBaseTokenIn = inTokenAddress == baseToken;

        uint256 lpAmount;
        if (isBaseTokenIn) {
            lpAmount = (basePrice * inTokenAmount) / lpPrice;
            IERC20(baseToken).transferFrom(msg.sender, lpToken, inTokenAmount);
        } else {
            lpAmount = (quotePrice * inTokenAmount) / lpPrice;
            IERC20(quoteToken).transferFrom(msg.sender, lpToken, inTokenAmount);
        }

        IOracleSwapPair(lpToken).mint(msg.sender, lpAmount);

        emit AddLiquidity(
            msg.sender,
            inTokenAddress,
            inTokenAmount,
            block.timestamp
        );
    }

    // Remove liquidty
    function removeLiquidity(
        uint256 lpAmount,
        address outTokenAddress,
        bytes[] calldata pythUpdateData
    ) external payable nonZeroOracleSwapPair {
        uint256 lpTotalSupply = IOracleSwapPair(lpToken).totalSupply();
        require(lpAmount <= lpTotalSupply, "OS: invalid lp amount to burn");

        (uint256 basePrice, uint256 quotePrice) = _getPrices(pythUpdateData);

        uint256 lpPrice = 1e18;

        if (lpTotalSupply > 0) {
            uint256 baseAmount = IOracleSwapPair(lpToken).baseBalance();
            uint256 quoteAmount = IOracleSwapPair(lpToken).quoteBalance();
            lpPrice =
                (basePrice * baseAmount + quotePrice * quoteAmount) /
                lpTotalSupply;
        }

        bool isBaseTokenOut = outTokenAddress == baseToken;

        uint256 outTokenAmount;
        if (isBaseTokenOut) {
            outTokenAmount = (lpPrice * lpAmount) / basePrice;
            IERC20(baseToken).transferFrom(lpToken, msg.sender, outTokenAmount);
        } else {
            outTokenAmount = (lpPrice * lpAmount) / quotePrice;
            IERC20(quoteToken).transferFrom(
                lpToken,
                msg.sender,
                outTokenAmount
            );
        }

        IOracleSwapPair(lpToken).burn(msg.sender, lpAmount);

        emit RemoveLiquidity(
            msg.sender,
            outTokenAddress,
            outTokenAmount,
            block.timestamp
        );
    }

    // set LP token(OracleswapPair) address
    function setLpToken(address lpToken_) external onlyOwner {
        require(lpToken_ != address(0), "OS: zero address set");
        lpToken = lpToken_;

        emit LpTokenUpdated(msg.sender, lpToken_, block.timestamp);
    }

    // Get prices of baseToken and quoteToken
    function _getPrices(
        bytes[] calldata pythUpdateData
    ) internal returns (uint256 basePrice, uint256 quotePrice) {
        uint updateFee = _pyth.getUpdateFee(pythUpdateData);
        _pyth.updatePriceFeeds{value: updateFee}(pythUpdateData);

        PythStructs.Price memory currentBasePrice = _pyth.getPrice(
            _baseTokenPriceId
        );
        PythStructs.Price memory currentQuotePrice = _pyth.getPrice(
            _quoteTokenPriceId
        );

        basePrice = _convertToUint(currentBasePrice, 18);
        quotePrice = _convertToUint(currentQuotePrice, 18);
    }

    // TODO: we should probably move something like this into the solidity sdk
    function _convertToUint(
        PythStructs.Price memory price,
        uint8 targetDecimals
    ) private pure returns (uint256) {
        if (price.price < 0 || price.expo > 0 || price.expo < -255) {
            revert();
        }

        uint8 priceDecimals = uint8(uint32(-1 * price.expo));

        if (targetDecimals >= priceDecimals) {
            return
                uint(uint64(price.price)) *
                10 ** uint32(targetDecimals - priceDecimals);
        } else {
            return
                uint(uint64(price.price)) /
                10 ** uint32(priceDecimals - targetDecimals);
        }
    }

    // Reinitialize the parameters of this contract.
    // (This function is for demo purposes only. You wouldn't include this on a real contract.)
    function reinitialize(
        bytes32 baseTokenPriceId_,
        bytes32 quoteTokenPriceId_,
        address baseToken_,
        address quoteToken_
    ) external onlyOwner {
        _baseTokenPriceId = baseTokenPriceId_;
        _quoteTokenPriceId = quoteTokenPriceId_;
        baseToken = baseToken_;
        quoteToken = quoteToken_;
    }

    receive() external payable {}
}
