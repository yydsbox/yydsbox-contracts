// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "./IRandomAccessor.sol";
import "./IRandomReceiver.sol";

contract LinkRandomAccessor is IRandomAccessor, Ownable, VRFConsumerBase {
    // 0.1 LINK
    uint256 public fee = 1e17;
    bytes32 private _keyHash;

    IRandomReceiver public randomReceiver;

    constructor(address vrfCoordinator_, address link_, bytes32 keyHash_) VRFConsumerBase(vrfCoordinator_, link_) {
        _keyHash = keyHash_;
    }

    function setFee(uint256 fee_) external onlyOwner {
        fee = fee_;
    }

    function setRandomReceiver(IRandomReceiver randomReceiver_) external onlyOwner {
        randomReceiver = randomReceiver_;
    }

    function requestRandom() external override returns (bytes32) {
        require(address(randomReceiver) == _msgSender(), "LinkRandomAccessor: no permission");
        require(LINK.balanceOf(address(this)) >= fee, "LinkRandomAccessor: not enough LINK");
        
        return requestRandomness(_keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomReceiver.onRandomReceived(requestId, randomness);
    }
}
