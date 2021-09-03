// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./IBoxPrize.sol";

contract BoxPrize is IBoxPrize, Ownable, ERC721Enumerable {
    struct Prize {
        uint256 prizeId;
        uint256 amount;
        bool claimed;
        address createdBy;
        uint256 createdAt;
    }

    address public minter;
    uint256 private _prizeIdTracker = 10000;

    mapping(uint256 => Prize) private _prizes;

    constructor() ERC721("JF Box Prize", "JFBP") {}

    modifier onlyMinter() {
        require(_msgSender() == minter, "BoxPrize: not the minter");
        _;
    }

    function setMinter(address minter_) external onlyOwner {
        require(minter_ != address(0), "BoxPrize: minter invalid");
        require(minter == address(0), "BoxPrize: minter already exists");

        minter = minter_;

        renounceOwnership();
    }

    function create(address owner, uint256 amount) external override onlyMinter returns (uint256) {
        address sender = _msgSender();
        uint256 prizeId = _prizeIdTracker++;

        _mint(owner, prizeId);

        Prize memory _prize = Prize(prizeId, amount, false, sender, block.timestamp);
        _prizes[prizeId] = _prize;

        return prizeId;
    }

    function setClaimed(uint256 prizeId) external override onlyMinter {
        require(_exists(prizeId), "BoxPrize: prize not exists");

        _prizes[prizeId].claimed = true;
    }

    function exists(uint256 prizeId) external override view returns (bool) {
        return _exists(prizeId);
    }

    function isClaimed(uint256 prizeId) external override view returns (bool) {
        return _prizes[prizeId].claimed;
    }

    function getPrize(uint256 prizeId_) external override view returns (uint256 prizeId, address owner, uint256 amount, bool claimed, address createdBy, uint256 createdAt) {
        if(_exists(prizeId_)) {
            Prize memory _prize = _prizes[prizeId_];

            prizeId = _prize.prizeId;
            amount = _prize.amount;
            claimed = _prize.claimed;
            createdBy = _prize.createdBy;
            createdAt = _prize.createdAt;

            owner = ownerOf(prizeId_);
        }
    }
}