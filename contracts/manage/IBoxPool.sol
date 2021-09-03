// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IBoxPoolBase.sol";

interface IBoxPool is IBoxPoolBase {
    struct PoolInfo {
        uint256 poolId;
        uint256 startAt;
        uint256 endAt;
        uint256 price;
        uint256 priceRatio;
        uint256[] returnRange;
        uint256[] awardsOdds;
        uint256[] awardsRatios;
        uint256 minQuantity;
        uint256 index;
    }

    struct PoolData {
        uint256 poolId;
        uint256 amount;
        uint256 quantity;
        bool published;
        uint256 accountCount;
        uint256[] awards;
    }

    struct PrizeInfo {
        uint256 prizeId;
        uint256 amount;
        address owner;
        bool claimed;
        address createdBy;
        uint256 createdAt;
    }

    struct TicketInfo {
        uint256 ticketId;
        uint256 poolId;
        uint256 fromId;
        uint256 toId;
        uint256 prizeId;
        uint256 returned;
        address owner;
        bool claimed;
        bool expired;
    }

    struct WinnerInfo {
        uint256 boxId;
        uint256 poolId;
        uint256 ticketId;
        uint256 index;
        uint256 amount;
        uint256 prizeId;
        bool claimed;
        address owner;
    }

    event Swap(uint256 indexed poolId, uint256 ticketId, uint256 fromId, uint256 toId);
    event OpenTicket(uint256 indexed poolId, uint256 ticketId, uint256 prizeId, uint256 amount);
    event OpenBox(uint256 indexed poolId, uint256 ticketId, uint256 boxId, uint256 prizeId, uint256 amount);
    event Buyback(uint256 prizeId, uint256 amount);

    function swap(uint256 poolId, uint256 count) external;
    function openTicket(uint256 ticketId) external;
    function openBox(uint256 ticketId, uint256 boxId) external;
    function buyback(uint256 prizeId) external;

    function getLatestPoolId() external view returns (uint256);

    function getPoolData(uint256 poolId) external view returns (PoolData memory result);
    function getPoolInfo(uint256 poolId) external view returns (PoolInfo memory result);
    function getBoxQuantity(uint256 poolId, address account) external view returns (uint256);
    function getWinners(uint256 poolId) external view returns (WinnerInfo[] memory result);

    function getTicket(uint256 ticketId) external view returns (TicketInfo memory result);
    function getTicketIds(address account, uint256 poolId) external view returns (uint256[] memory);
    function overview(address account) external view returns (uint256[] memory poolIds, uint256 returned, uint256 unopened, uint256 expired);

    function getPrize(uint256 prizeId_) external view returns (PrizeInfo memory result);
}