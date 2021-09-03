// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IRandomAccessor.sol";

interface IExternalRandomAccessor is IRandomAccessor {
    function fulfillRandomness(bytes32 requestId, uint256 randomness) external;
}