// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./IExternalRandomAccessor.sol";
import "./IRandomReceiver.sol";

contract ExternalRandomAccessor is IExternalRandomAccessor, Ownable {
    IRandomReceiver public randomReceiver;

    function setRandomReceiver(IRandomReceiver randomReceiver_) external onlyOwner {
        randomReceiver = randomReceiver_;
    }

    function requestRandom() external override view returns (bytes32) {
        require(address(randomReceiver) == _msgSender(), "ExternalRandomAccessor: no permission");

        return keccak256(abi.encodePacked(
            block.number,
            block.timestamp,
            block.difficulty,
            block.gaslimit,
            block.coinbase,
            address(this),
            randomReceiver
        ));
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) external override onlyOwner {
        randomReceiver.onRandomReceived(requestId, randomness);
    }
}
