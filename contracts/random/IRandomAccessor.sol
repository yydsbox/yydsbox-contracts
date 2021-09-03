// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandomAccessor {
    function requestRandom() external returns (bytes32);
}