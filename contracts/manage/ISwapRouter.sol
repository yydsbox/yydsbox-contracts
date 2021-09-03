// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISwapRouter {
  function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}