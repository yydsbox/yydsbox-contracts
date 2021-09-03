// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFeeCollector {
    event CollectFee(address token, address payer, uint256 amount);

    function token() external view returns (IERC20);

    function collect(uint256 amount) external;
}