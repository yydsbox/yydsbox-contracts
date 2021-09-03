// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IRandomGenerator.sol";

contract RandomGenerator is IRandomGenerator {
  function random(uint256 seed) external override view returns (uint256) {
    return _random(seed);
  }

  // repeat
  function simpleRandoms(uint256 randomness, uint256 min, uint256 max, uint256 count) external override view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](count);

    uint256 seed = _random(randomness);
    uint256 _max = max - min;

    for(uint256 i = 0; i < count; i++) {
      result[i] = min + (seed % _max);
    }

    return result;
  }

  // floyd samples, PS: (max - min) >> count, no-repeat
  function randoms(uint256 randomness, uint256 min, uint256 max, uint256 count) external override view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](count);
    uint256 n = max - min + 1;
    uint256 r;
    uint256 length;
    uint256 i;

    uint256 seed = _random(randomness);
    for(i = n - count + 1; i <= n; i++) {
      r = seed % (i + 1);
      if(_findIndex(result, length, r) == length) {
        result[length] = r;
      } else {
        result[length] = i;
      }
      length++;
    }

    for(i = 0; i < count; i++) {
      result[i] += min;
    }

    seed = _random(seed);
    // shuffle
    for(i = 0; i < count; i++) {
      r = seed % (i + 1);
      n = result[i];
      result[i] = result[r];
      result[r] = n;
    }

    return result;
  }

  function _random(uint256 seed) private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_blockHash(), seed)));
  }

  function _blockHash() private view returns (bytes32) {
    return keccak256(abi.encodePacked(
      block.number,
      block.timestamp,
      block.difficulty,
      block.gaslimit,
      block.coinbase
    ));
  }

  function _findIndex(uint256[] memory array, uint256 length, uint256 value) private pure returns (uint256) {
    for(uint256 i = 0; i < length; i++) {
      if(array[i] == value) {
        return i;
      }
    }

    return length;
  }
}