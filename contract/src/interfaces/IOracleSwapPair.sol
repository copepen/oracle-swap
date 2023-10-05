pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IOracleSwapPair is IERC20 {
    function baseBalance() external view returns (uint256);

    function quoteBalance() external view returns (uint256);

    function mint(address from, uint amount) external;

    function burn(address to, uint amount) external;
}
