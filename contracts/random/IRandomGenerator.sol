// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandomGenerator {

  function random(uint256 seed) external view returns (uint256);

  function simpleRandoms(uint256 randomness, uint256 min, uint256 max, uint256 count) external view returns (uint256[] memory);

  function randoms(uint256 randomness, uint256 min, uint256 max, uint256 count) external view returns (uint256[] memory);
}