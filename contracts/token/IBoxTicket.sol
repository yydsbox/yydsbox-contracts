// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IBoxTicket is IERC721, IERC721Metadata, IERC721Enumerable {
    function create(address account, uint256 poolId, uint256 count) external returns (uint256 ticketId, uint256 fromId, uint256 toId);
    function setPrize(uint256 ticketId, uint256 prizeId, uint256 returned) external;
    function setClaimed(uint256 ticketId) external;

    function exists(uint256 ticketId) external view returns (bool);
    function isOpened(uint256 ticketId) external view returns (bool);
    function isValid(uint256 poolId, uint256 boxId) external view returns (bool);
    function getMinBoxId() external pure returns (uint256);
    function getTicket(uint256 ticketId_) external view returns (uint256 ticketId, address owner, uint256 poolId, uint256 fromId, uint256 toId, uint256 prizeId, uint256 returned, bool claimed);
    function getTicketId(uint256 poolId, uint256 boxId) external view returns (uint256);
    function getTicketIds(address account, uint256 poolId) external view returns (uint256[] memory);
    function overview(address account) external view returns (uint256[] memory poolIds, uint256 returned, uint256 unopened, uint256 expired);
}