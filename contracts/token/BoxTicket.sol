// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./IBoxTicket.sol";
import "../manage/IBoxPoolBase.sol";

contract BoxTicket is IBoxTicket, Ownable, ERC721Enumerable {
    struct Ticket {
        uint256 ticketId;
        uint256 poolId;
        uint256 fromId;
        uint256 toId;
        uint256 prizeId;
        uint256 returned;
        bool claimed;
    }

    uint256 private constant MIN_ID = 10000;
    address public minter;

    IBoxPoolBase private _boxPool;
    uint256 private _ticketIdTracker = MIN_ID;

    mapping(uint256 => Ticket) private _tickets;
    mapping(uint256 => uint256[]) private _poolTicketIds;
    mapping(uint256 => uint256) private _boxSupply;
    mapping(uint256 => mapping(address => uint256[])) private _ownerTicketIds;
    mapping(address => uint256[]) private _ownerPoolIds;

    constructor() ERC721("JF Box Ticket", "JFBT") {}

    modifier onlyMinter() {
        require(_msgSender() == minter, "BoxTicket: not the minter");
        _;
    }

    function setMinter(address minter_) external onlyOwner {
        require(minter_ != address(0), "BoxTicket: minter invalid");
        require(minter == address(0), "BoxTicket: minter already exists");

        minter = minter_;
        _boxPool = IBoxPoolBase(minter_);

        renounceOwnership();
    }

    function create(address account, uint256 poolId, uint256 count) external override onlyMinter returns (uint256 ticketId, uint256 fromId, uint256 toId) {
        ticketId = _ticketIdTracker++;

        _mint(account, ticketId);

        uint256 supply = _boxSupply[poolId];
        fromId = supply + 1 + MIN_ID;
        toId = supply + count + MIN_ID;

        _poolTicketIds[poolId].push(ticketId);
        _boxSupply[poolId] += count;

        Ticket memory ticket = Ticket(ticketId, poolId, fromId, toId, 0, 0, false);
        _tickets[ticketId] = ticket;
        _ownerTicketIds[poolId][account].push(ticketId);

        uint256 index = _findIndex(_ownerPoolIds[account], poolId);
        if (index == 0) {
            _ownerPoolIds[account].push(poolId);
        }
    }

    function setPrize(uint256 ticketId, uint256 prizeId, uint256 returned) external override onlyMinter {
        require(_exists(ticketId), "BoxTicket: ticket not exists");
        require(_tickets[ticketId].prizeId == 0, "BoxTicket: ticket already opened");

        _tickets[ticketId].prizeId = prizeId;
        _tickets[ticketId].returned = returned;
    }

    function setClaimed(uint256 ticketId) external override onlyMinter {
        require(_exists(ticketId), "BoxTicket: ticket not exists");
        require(!_tickets[ticketId].claimed, "BoxTicket: ticket already claimed");

        _tickets[ticketId].claimed = true;
    }

    function exists(uint256 ticketId) external override view returns (bool) {
        return _exists(ticketId);
    }

    function isOpened(uint256 ticketId) external override view returns (bool) {
        return _exists(ticketId) ? _tickets[ticketId].prizeId > 0 : false;
    }

    function isValid(uint256 poolId, uint256 boxId) external override view returns (bool) {
        return _isValid(poolId, boxId);
    }

    function getMinBoxId() external override pure returns (uint256) {
        return MIN_ID;
    }

    function getTicket(uint256 ticketId_) external override view returns (uint256 ticketId, address owner, uint256 poolId, uint256 fromId, uint256 toId, uint256 prizeId, uint256 returned, bool claimed) {
        if(_exists(ticketId_)) {
            Ticket memory ticket = _tickets[ticketId_];
            
            ticketId = ticket.ticketId;
            poolId = ticket.poolId;
            fromId = ticket.fromId;
            toId = ticket.toId;
            prizeId = ticket.prizeId;
            returned = ticket.returned;
            claimed = ticket.claimed;

            owner = ownerOf(ticketId_);
        }
    }

    function getTicketId(uint256 poolId, uint256 boxId) external override view returns (uint256) {
        return _isValid(poolId, boxId) ? _findTicketId(poolId, boxId) : 0;
    }

    function getTicketIds(address account, uint256 poolId) external override view returns (uint256[] memory) {
        return _ownerTicketIds[poolId][account];
    }

    function overview(address account) external override view returns (uint256[] memory poolIds, uint256 returned, uint256 unopened, uint256 expired) {
        uint256 balance = balanceOf(account);

        Ticket memory ticket;
        for(uint256 i = 0; i < balance; i++) {
            ticket = _tickets[tokenOfOwnerByIndex(account, i)];

            if(ticket.prizeId == 0) {
                _boxPool.isPublished(ticket.poolId) ? expired++ : unopened++;
            } else if(ticket.claimed) {
                returned += ticket.returned;
            }
        }

        poolIds = _ownerPoolIds[account];
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);

        uint256 poolId = _tickets[tokenId].poolId;
        uint256[] storage ticketIds = _ownerTicketIds[poolId][from];

        uint256 index = _findIndex(ticketIds, tokenId) - 1;
        _removeValue(ticketIds, index);

        if(ticketIds.length == 0) {
            index = _findIndex(_ownerPoolIds[from], poolId) - 1;
            _removeValue(_ownerPoolIds[from], index);
        }

        _ownerTicketIds[poolId][to].push(tokenId);
        if(_ownerPoolIds[to].length == 0) {
            _ownerPoolIds[to].push(poolId);
        }
    }

    function _isValid(uint256 poolId, uint256 boxId) private view returns (bool) {
        return boxId >= MIN_ID && _boxSupply[poolId] > 0 && _boxSupply[poolId] + MIN_ID >= boxId;
    }

    function _findTicketId(uint256 poolId, uint256 boxId) private view returns (uint256) {
        uint256[] storage ticketIds = _poolTicketIds[poolId];
        if(ticketIds.length == 0) {
            return 0;
        }

        uint256 left = 0; 
        uint256 right = ticketIds.length - 1;
        uint256 mid;

        while(left <= right) {
            mid = (right + left) / 2 | 0;

            if(left == mid && boxId <= _tickets[ticketIds[left]].toId) {
                break;
            } else if(left == mid && boxId <= _tickets[ticketIds[right]].toId) {
                mid = right;
                break;
            }
            
            if(_tickets[ticketIds[mid]].toId < boxId) {
                left = mid;
            } else {
                right = mid;
            }
        }
        
        return ticketIds[mid];
    }

    function _findIndex(uint256[] memory array, uint256 value) private pure returns (uint256) {
        for(uint256 i = 0; i < array.length; i++) {
            if(array[i] == value) {
                return i + 1;
            }
        }

        return 0;
    }

    function _removeValue(uint256[] storage array, uint256 index) private {
        uint256 lastIndex = array.length - 1;
        uint256 lastValue = array[lastIndex];
        array[lastIndex] = array[index];
        array[index] = lastValue;
        array.pop();
    }
}
