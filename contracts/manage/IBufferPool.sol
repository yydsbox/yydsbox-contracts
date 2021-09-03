// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBufferPool {
    event Supply(uint256 amount, uint256 balance);

    function token() external view returns (IERC20);
    function balance() external view returns (uint256);

    function supply(uint256 amount) external;
}