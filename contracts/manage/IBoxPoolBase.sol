// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBoxPoolBase {
  function isPublished(uint256 poolId) external view returns (bool);
}