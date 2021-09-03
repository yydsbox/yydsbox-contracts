// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IBoxPrize is IERC721, IERC721Metadata {
    function create(address owner, uint256 amount) external returns (uint256);
    function setClaimed(uint256 prizeId) external;

    function exists(uint256 prizeId) external view returns (bool);
    function isClaimed(uint256 prizeId) external view returns (bool);
    function getPrize(uint256 prizeId_) external view returns (uint256 prizeId, address owner, uint256 amount, bool claimed, address createdBy, uint256 createdAt);
}