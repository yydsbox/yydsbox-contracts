// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBoxController {
    function token() external view returns (address);
    function boxTicket() external view returns (address);
    function boxPrize() external view returns (address);

    function randomAccessor() external view returns (address);
    function randomGenerator() external view returns (address);
    function feeCollector() external view returns (address);
    function fee() external view returns (uint256);

    function setRandomAccessor(address randomAccessor_) external;
    function setRandomGenerator(address randomGenerator_) external;
    function setFeeCollector(address feeCollector_) external;
    function setFee(uint256 fee_) external;

    function getRandomRequestId(uint256 poolId) external view returns (bytes32);
    function isRandomnessReady(uint256 poolId) external view returns (bool);

    function create(
        uint256 startAt,
        uint256 endAt,
        uint256 price,
        uint256 priceRatio,
        uint256[] memory returnRange,
        uint256[] memory awardsOdds,
        uint256[] memory awardsRatios
    ) external;
    function tryPublish(uint256 poolId) external;
    function publish(uint256 poolId) external;
}