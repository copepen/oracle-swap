// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Example OracleswapPair contract
contract OracleSwapPair is ERC20 {
    address public baseToken;
    address public quoteToken;
    address public oracleSwap;

    modifier onlyOracleSwap() {
        require(msg.sender == oracleSwap, "Caller is not oracle swap");
        _;
    }

    modifier nonZeroAmount(uint256 amount_) {
        require(amount_ > 0, "OSP: zero mint amount");
        _;
    }

    constructor(
        address baseToken_,
        address quoteToken_,
        address oracleSwap_
    ) ERC20("OracleSwap LP", "OSLP") {
        baseToken = baseToken_;
        quoteToken = quoteToken_;
        oracleSwap = oracleSwap_;

        IERC20(baseToken).approve(oracleSwap, type(uint256).max);
        IERC20(quoteToken).approve(oracleSwap, type(uint256).max);
    }

    // Mint OSLP
    function mint(address to_, uint256 amount_) external onlyOracleSwap {
        require(amount_ > 0, "OSP: zero mint amount");
        _mint(to_, amount_);
    }

    // Burn OSLP
    function burn(address from_, uint256 amount_) external onlyOracleSwap {
        require(amount_ > 0, "OSP: zero burn amount");
        _burn(from_, amount_);
    }

    // Get the number of base tokens in the pool
    function baseBalance() public view returns (uint256) {
        return IERC20(baseToken).balanceOf(address(this));
    }

    // Get the number of quote tokens in the pool
    function quoteBalance() public view returns (uint256) {
        return IERC20(quoteToken).balanceOf(address(this));
    }

    receive() external payable {}
}
