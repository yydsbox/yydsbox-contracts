// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../random/IRandomGenerator.sol";
import "../random/IRandomAccessor.sol";
import "../random/IRandomReceiver.sol";
import "../token/IBoxTicket.sol";
import "../token/IBoxPrize.sol";
import "./IBoxController.sol";
import "./IBoxPool.sol";
import "./IFeeCollector.sol";

contract BoxPool is IBoxController, IBoxPool, IRandomReceiver, ReentrancyGuard, Ownable, ERC721Holder {
    using SafeERC20 for IERC20;

    enum BuybackType {
        Ticket,
        Box
    }

    struct BuybackInfo {
        uint256 prizeId;
        uint256 ticketId;             
        uint256 poolId;              // winner pool
        uint256 index;               // winner index
        BuybackType buybackType;     // 回购类型
    }

    struct Winner {
        uint256 boxId;                // Box id
        uint256 poolId;               // BoxPool id
        uint256 ticketId;             // BoxTicket id
        uint256 index;                // 第几个奖
        uint256 amount;               // 奖励数量
        uint256 prizeId;              // BoxPrize id
        bool claimed;                 // 是否已领取
        address claimedBy;            // 领取者
    }

    struct Pool {
        uint256 poolId;                               // poolId
        uint256 startAt;                              // 开始时间
        uint256 endAt;                                // 结束时间
        uint256 price;                                // 基础价格
        uint256 priceRatio;                           // 价格返还比率(除以100)
        uint256[] returnRange;                        // 返还概率(除以100), [最少，最多]
        uint256[] awardsOdds;                         // 各奖项数量
        uint256[] awardsRatios;                       // 奖项占总奖金比例(除以1000000)
        uint256 minQuantity;                          // 最小参与数量
        uint256 index;

        mapping (uint256 => uint256) returnAmounts;   // 返还概率数字对应的返还数量(缓存结果，避免重复计算)

        uint256 quantity;                             // 总数
        uint256 amount;                               // 总奖金
        uint256 balance;                              // 实际余额
        mapping (address => uint256) accountsQuantity;// 各账号购买的box数量
        uint256 accountCount;                         // 账号数量

        bytes32 requestId;                            // 请求随机数的ID
        uint256 randomness;                           // 随机数
        bool published;                               // 是否已发布
        uint256[] awards;                             // 各奖项奖励
        Winner[] winners;                             // 获奖者(boxId => Winner)
        mapping (uint256 => uint256) winnersIndex;    // boxId => index + 1
    }

    uint256 private constant BASE_RATIO = 1e2;
    uint256 private constant AWARDS_RATIO = 1e6;
    uint256 private constant FEE_RATIO = 1e4;
    uint256 private constant MIN_ID = 1e4;

    IERC20 private _token;
    IBoxTicket private _boxTicket;
    IBoxPrize private _boxPrize;

    IRandomAccessor private _randomAccessor;
    IRandomGenerator private _randomGenerator;
    IFeeCollector private _feeCollector;
    uint256 private _fee = 900;  // 9%

    uint256 private _poolIdTracker = MIN_ID;

    mapping (uint256 => Pool) private _pools;
    mapping (bytes32 => uint256) private _requestIds;

    mapping (uint256 => BuybackInfo) private _prizeBuybacks;

    event Created(uint256 indexed poolId, address sender, uint256 startAt, uint256 endAt, uint256 index);
    event Published(uint256 indexed poolId, address sender, uint256 publishAt, uint256 index);
    event RequestRandom(uint256 indexed poolId, bytes32 requestId);
    event RandomReceived(uint256 indexed poolId, bytes32 requestId, uint256 randomness);

    modifier onlyValid(uint256 poolId) {
        require(_isValid(poolId), "BoxPool: pool not exists");
        _;
    }

    modifier onlyStarted(uint256 poolId) {
        require(_isStarted(poolId), "BoxPool: not started");
        _;
    }

    modifier onlyNotEnded(uint256 poolId) {
        require(!_isEnded(poolId), "BoxPool: already ended");
        _;
    }

    modifier onlyEnded(uint256 poolId) {
        require(_isEnded(poolId), "BoxPool: not ended");
        _;
    }

    modifier onlyNotPublished(uint256 poolId) {
        require(!_isPublished(poolId), "BoxPool: already published");
        _;
    }

    modifier onlyPublished(uint256 poolId) {
        require(_isPublished(poolId), "BoxPool: not published");
        _;
    }

    modifier onlyTicketExists(uint256 ticketId) {
        require(_boxTicket.exists(ticketId), "BoxPool: ticket not exists");
        _;
    }

    modifier onlyOwnable(address owner) {
        require(owner == _msgSender(), "BoxPool: not the owner");
        _;
    }

    constructor(address token_, address boxTicket_, address boxPrize_) {
        _token = IERC20(token_);
        _boxTicket = IBoxTicket(boxTicket_);
        _boxPrize = IBoxPrize(boxPrize_);
    }

    function token() external override view returns (address) {
        return address(_token);
    }

    function boxTicket() external override view returns (address) {
        return address(_boxTicket);
    }

    function boxPrize() external override view returns (address) {
        return address(_boxPrize);
    }

    function randomAccessor() external override view returns (address) {
        return address(_randomAccessor);
    }

    function randomGenerator() external override view returns (address) {
        return address(_randomGenerator);
    }

    function feeCollector() external override view returns (address) {
        return address(_feeCollector);
    }

    function fee() external override view returns (uint256) {
        return _fee;
    }

    function setRandomAccessor(address randomAccessor_) external override onlyOwner {
        _randomAccessor = IRandomAccessor(randomAccessor_);
    }

    function setRandomGenerator(address randomGenerator_) external override onlyOwner {
        _randomGenerator = IRandomGenerator(randomGenerator_);
    }

    function setFeeCollector(address feeCollector_) external override onlyOwner {
        _feeCollector = IFeeCollector(feeCollector_);
    }

    function setFee(uint256 fee_) external override onlyOwner {
        require(fee_ < FEE_RATIO, "BoxPool: invalid fee");
        _fee = fee_;
    }

    function create(
        uint256 startAt,
        uint256 endAt,
        uint256 price,
        uint256 priceRatio,
        uint256[] memory returnRange,
        uint256[] memory awardsOdds,
        uint256[] memory awardsRatios
    ) external override onlyOwner {
        require(startAt < endAt, "BoxPool: startAt must less than endAt");
        require(endAt > _getTimestamp(), "BoxPool: endAt invalid");
        require(priceRatio <= BASE_RATIO, "BoxPool: priceRatio invalid");
        require(returnRange.length == 2 && returnRange[0] < returnRange[1], "BoxPool: returnRange invalid");
        require(awardsOdds.length == awardsRatios.length, "BoxPool: awards length not match");
        require(_calcSum(awardsRatios) == AWARDS_RATIO, "BoxPool: awards invalid");

        uint256 pooldId = _poolIdTracker++;
        Pool storage pool = _pools[pooldId];
        pool.poolId = pooldId;
        pool.startAt = startAt;
        pool.endAt = endAt;
        pool.price = price;
        pool.priceRatio = priceRatio;
        pool.returnRange = returnRange;
        pool.awardsOdds = awardsOdds;
        pool.awardsRatios = awardsRatios;
        pool.index = _poolIdTracker - MIN_ID;

        uint256 i;
        for(i = returnRange[0]; i <= returnRange[1]; i++) {
            pool.returnAmounts[i] = price * priceRatio * i / BASE_RATIO / BASE_RATIO;
        }

        uint256 minQuantity;
        for(i = 0; i < awardsOdds.length; i++) {
            minQuantity += awardsOdds[i];
        }
        pool.minQuantity = minQuantity;

        emit Created(pool.poolId, _msgSender(), pool.startAt, pool.endAt, pool.index);
    }

    function swap(uint256 poolId, uint256 count) external override onlyValid(poolId) onlyStarted(poolId) onlyNotEnded(poolId) {
        require(count > 0, "BoxPool: count must greater than 0");

        address sender = _msgSender();
        Pool storage pool = _pools[poolId];

        uint256 totalAmount = pool.price * count;
        require(_token.balanceOf(sender) >= totalAmount, "BoxPool: insufficient balance");

        _token.safeTransferFrom(sender, address(this), totalAmount);

        pool.quantity += count;
        pool.balance += totalAmount;
        if(pool.accountsQuantity[sender] == 0) {
            pool.accountCount++;
        }
        pool.accountsQuantity[sender] += count;

        (uint256 ticketId, uint256 fromId, uint256 toId) = _boxTicket.create(sender, poolId, count);

        emit Swap(poolId, ticketId, fromId, toId);
    }

    function openTicket(uint256 ticketId) external override onlyTicketExists(ticketId) {
        (, address owner, uint256 poolId, uint256 fromId, uint256 toId, uint256 prizeId, ,) = _boxTicket.getTicket(ticketId);
        require(prizeId == 0, "BoxPool: ticket already opened");

        _openTicket(poolId, ticketId, fromId, toId, owner);
    }

    function openBox(uint256 ticketId, uint256 boxId) external override onlyTicketExists(ticketId) {
        (, address owner, uint256 poolId, , , , ,) = _boxTicket.getTicket(ticketId);
        require(_boxTicket.isValid(poolId, boxId), "BoxPool: box not exists");
        require(_pools[poolId].winnersIndex[boxId] > 0, "BoxPool: not the winner");
        
        _openBox(poolId, ticketId, boxId, owner);
    }

    function buyback(uint256 prizeId) external override {
        require(_boxPrize.exists(prizeId), "BoxPool: prize not exists");
        require(!_boxPrize.isClaimed(prizeId), "BoxPool: prize already buyback");

        (, address owner, uint256 amount, , , )= _boxPrize.getPrize(prizeId);
        require(owner == _msgSender(), "BoxPool: not the owner");

        BuybackInfo memory buybackInfo = _prizeBuybacks[prizeId];
        if(buybackInfo.buybackType == BuybackType.Ticket) {
            _boxTicket.setClaimed(buybackInfo.ticketId);
        } else {
            Winner storage winner = _pools[buybackInfo.poolId].winners[buybackInfo.index];
            winner.claimed = true;
            winner.claimedBy = owner;
        }

        _boxPrize.setClaimed(prizeId);
        _boxPrize.safeTransferFrom(owner, address(this), prizeId);
        _token.safeTransfer(owner, amount);

        emit Buyback(prizeId, amount);
    }

    function tryPublish(uint256 poolId) external override nonReentrant onlyValid(poolId) onlyEnded(poolId) onlyNotPublished(poolId) {
        require(_isFulfilled(poolId), "BoxPool: not fulfilled");
        require(!_isRandomnessReady(poolId), "BoxPool: randomness is ready");

        bytes32 requestId = _randomAccessor.requestRandom();
        _requestIds[requestId] = poolId;
        _pools[poolId].requestId = requestId;

        emit RequestRandom(poolId, requestId);
    }

    function publish(uint256 poolId) external override nonReentrant onlyValid(poolId) onlyEnded(poolId) onlyNotPublished(poolId) {
        require(_isRandomnessReady(poolId), "BoxPool: randomness not ready");

        Pool storage pool = _pools[poolId];

        pool.amount = _calcAvailableAmount(poolId);
        pool.awards = _calcAwards(poolId, pool.amount);

        uint256 sum = pool.awardsOdds[0];
        uint256 minBoxId = _boxTicket.getMinBoxId();
        uint256[] memory boxIds = _randomGenerator.randoms(pool.randomness, minBoxId, minBoxId + pool.quantity - 1, pool.minQuantity);
        
        uint256 ticketId;
        uint256 boxId;
        uint256 index;
        for(uint256 i = 0; i < boxIds.length; i++) {
            if(i == sum && index + 1 < pool.awardsOdds.length) {
                index++;
                sum += pool.awardsOdds[index];
            } 
            
            boxId = boxIds[i];
            pool.winnersIndex[boxId] = i + 1;
            
            ticketId = _boxTicket.getTicketId(poolId, boxId);
            Winner memory winner = Winner(boxId, poolId, ticketId, index, pool.awards[index], 0, false, address(0));
            pool.winners.push(winner);
        }

        _collectFee(poolId);
        pool.published = true;

        emit Published(pool.poolId, _msgSender(), _getTimestamp(), pool.index);
    }

    function onRandomReceived(bytes32 requestId, uint256 randomness) external override nonReentrant {
        require(_msgSender() == address(_randomAccessor), "BoxPool: invalid caller");
        require(randomness != 0, "BoxPool: invalid randomness");

        _fillRandomness(_requestIds[requestId], requestId, randomness);
    }

    function isPublished(uint256 poolId) external override view returns (bool) {
        return _pools[poolId].published;
    }

    function getLatestPoolId() external override view returns (uint256) {
        return _poolIdTracker > MIN_ID ? _poolIdTracker - 1 : 0;
    }

    function getPoolData(uint256 poolId) external override view returns (PoolData memory result) {
        if(_isValid(poolId)) {
            Pool storage pool = _pools[poolId];

            uint256 amount;
            uint256[] memory awards;
            if(pool.published) {
                amount = pool.amount;
                awards = pool.awards;
            } else {
                amount = _calcAvailableAmount(poolId);
                awards = _calcAwards(poolId, amount);
            }

            result = PoolData(pool.poolId, amount, pool.quantity, pool.published, pool.accountCount, awards);
        }
    }

    function getPoolInfo(uint256 poolId) external override view returns (PoolInfo memory result) {
        if(_isValid(poolId)) {
            Pool storage pool = _pools[poolId];

            result = PoolInfo(
                pool.poolId,
                pool.startAt,
                pool.endAt,
                pool.price,
                pool.priceRatio,
                pool.returnRange,
                pool.awardsOdds,
                pool.awardsRatios,
                pool.minQuantity,
                pool.index
            );
        }
    }

    function getBoxQuantity(uint256 poolId, address account) external override view returns (uint256) {
        return _pools[poolId].accountsQuantity[account];
    }

    function getWinners(uint256 poolId) external override view returns (WinnerInfo[] memory result) {
        Winner[] memory winners = _pools[poolId].winners;
        uint256 length = winners.length;
        result = new WinnerInfo[](length);

        Winner memory winner;
        address owner;
        for(uint256 i = 0; i < length; i++) {
            winner = winners[i];
            owner = winner.prizeId == 0 ? _boxTicket.ownerOf(winner.ticketId) : winner.claimed ? winner.claimedBy : _boxPrize.ownerOf(winner.prizeId);
            
            result[i] = WinnerInfo(
                winner.boxId,
                winner.poolId,
                winner.ticketId,
                winner.index,
                winner.amount,
                winner.prizeId,
                winner.claimed,
                owner
            );
        }
    }

    function getTicket(uint256 ticketId_) external override view returns (TicketInfo memory result) {
        (uint256 ticketId, address owner, uint256 poolId, uint256 fromId, uint256 toId, uint256 prizeId, uint256 returned, bool claimed) = _boxTicket.getTicket(ticketId_);
        
        result = TicketInfo(
            ticketId,
            poolId,
            fromId,
            toId,
            prizeId,
            returned,
            owner,
            claimed,
            _pools[poolId].published
        );
    }

    function getTicketIds(address account, uint256 poolId) external override view returns (uint256[] memory) {
        return _boxTicket.getTicketIds(account, poolId);
    }

    function overview(address account) external override view returns (uint256[] memory poolIds, uint256 returned, uint256 unopened, uint256 expired) {
        return _boxTicket.overview(account);
    }

    function getPrize(uint256 prizeId_) external override view returns (PrizeInfo memory) {
        (uint256 prizeId, address owner, uint256 amount, bool claimed, address createdBy, uint256 createdAt) = _boxPrize.getPrize(prizeId_);

        return PrizeInfo(
            prizeId,
            amount,
            owner,
            claimed,
            createdBy,
            createdAt
        );
    }

    function getRandomRequestId(uint256 poolId) external override view returns (bytes32) {
        return _isValid(poolId) ? _pools[poolId].requestId : bytes32(uint256(0));
    }

    function isRandomnessReady(uint256 poolId) external override view returns (bool) {
        return _isValid(poolId) ? _isRandomnessReady(poolId) : false;
    }

    function _openTicket(uint256 poolId, uint256 ticketId, uint256 fromId, uint256 toId, address owner) private onlyValid(poolId) onlyNotPublished(poolId) onlyOwnable(owner) {
        require(!_boxTicket.isOpened(ticketId), "BoxPool: ticket already opened");

        uint256 returnAmount = _calcReturn(poolId, toId - fromId + 1, owner);
        _pools[poolId].balance -= returnAmount;

        uint256 prizeId = _boxPrize.create(owner, returnAmount);
        _boxTicket.setPrize(ticketId, prizeId, returnAmount);

        BuybackInfo memory buybackInfo = BuybackInfo(prizeId, ticketId, 0, 0, BuybackType.Ticket);
        _prizeBuybacks[prizeId] = buybackInfo;

        emit OpenTicket(poolId, ticketId, prizeId, returnAmount);
    }

    function _openBox(uint256 poolId, uint256 ticketId, uint256 boxId, address owner) private onlyValid(poolId) onlyPublished(poolId) onlyOwnable(owner) {
        Pool storage pool = _pools[poolId];
        uint256 index = pool.winnersIndex[boxId] - 1;
        Winner storage winner = pool.winners[index];
        require(winner.prizeId == 0, "BoxPool: box already opened");

        uint256 prizeId = _boxPrize.create(owner, winner.amount);
        winner.prizeId = prizeId;

        BuybackInfo memory buybackInfo = BuybackInfo(prizeId, 0, poolId, index, BuybackType.Box);
        _prizeBuybacks[prizeId] = buybackInfo;

        emit OpenBox(poolId, ticketId, boxId, prizeId, winner.amount);
    }

    function _collectFee(uint256 poolId) private {
        uint256 feeAmount = _calcFee(poolId);

        _token.safeApprove(address(_feeCollector), feeAmount);
        _feeCollector.collect(feeAmount);

        _pools[poolId].balance -= feeAmount;
    }

    function _fillRandomness(uint256 poolId, bytes32 requestId, uint256 randomness) private onlyValid(poolId) onlyEnded(poolId) onlyNotPublished(poolId) {
        Pool storage pool = _pools[poolId];
        require(pool.requestId == requestId, "BoxPool: invalid requestId");

        pool.randomness = randomness;

        emit RandomReceived(poolId, requestId, randomness);
    }

    function _calcAwards(uint256 poolId, uint256 availableAmount) private view returns (uint256[] memory) {
        Pool storage pool = _pools[poolId];

        uint256 length = pool.awardsOdds.length;
        uint256[] memory result = new uint256[](length);
        for(uint256 i = 0; i < length; i++) {
            result[i] = availableAmount * pool.awardsRatios[i] / AWARDS_RATIO / pool.awardsOdds[i];
        }

        return result;
    }

    function _calcAvailableAmount(uint256 poolId) private view returns (uint256) {
        return _pools[poolId].balance - _calcFee(poolId);
    }

    function _calcFee(uint256 poolId) private view returns (uint256) {
        return _pools[poolId].quantity * _pools[poolId].price * _fee / FEE_RATIO;
    }

    function _calcSum(uint256[] memory arr) private pure returns (uint256) {
        uint256 sum;
        uint256 length = arr.length;
        for(uint256 i = 0; i < length; i++) {
            sum += arr[i];
        }
        return sum;
    }

    function _calcReturn(uint256 poolId, uint256 count, address sender) private view returns (uint256) {
        Pool storage pool = _pools[poolId];

        uint256 times = Math.min(count, 100);
        uint256 randomness = _randomGenerator.random(uint256(keccak256(abi.encodePacked(pool.quantity, pool.balance, count, sender))));
        // 简单重复抽样
        uint256[] memory randoms = _randomGenerator.simpleRandoms(randomness, pool.returnRange[0], pool.returnRange[1] + 1, times);

        uint256 returnAmount;
        for(uint256 i = 0; i < times; i++) {
            returnAmount += pool.returnAmounts[randoms[i]];
        }

        return returnAmount * count / times;
    }

    function _isValid(uint256 poolId) private view returns (bool) {
        return poolId >= MIN_ID && poolId < _poolIdTracker;
    }

    function _isStarted(uint256 poolId) private view returns (bool) {
        return _pools[poolId].startAt < _getTimestamp();
    }

    function _isEnded(uint256 poolId) private view returns (bool) {
        return _pools[poolId].endAt < _getTimestamp();
    }

    function _isFulfilled(uint256 poolId) private view returns (bool) {
        return _pools[poolId].quantity >= _pools[poolId].minQuantity;
    }

    function _isRandomnessReady(uint256 poolId) private view returns (bool) {
        return _pools[poolId].randomness > 0;
    }

    function _isPublished(uint256 poolId) private view returns (bool) {
        return _pools[poolId].published;
    }

    function _getTimestamp() private view returns (uint256) {
        return block.timestamp;
    }
}