// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IFeeCollector.sol";
import "./ISwapRouter.sol";

contract FeeCollector is IFeeCollector, Context {
    using SafeERC20 for IERC20;

    uint256 private constant BASE_RATIO = 900;
    
    IERC20 public override token;
    address public buybackToken;

    ISwapRouter public swapRouter;
    
    address public target;
    address public developer;

    uint256 public burnFee = 300;        // 33.33%    3%
    uint256 public buybackFee = 300;     // 33.33%    3%
    uint256 public partnerFee = 150;     // 16.67%  1.5%
    uint256 public developerFee = 150;   // 16.67%  1.5%

    constructor(address token_, address target_, address buybackToken_, address swapRouter_) {
        token = IERC20(token_);
        target = target_;
        buybackToken = buybackToken_;
        swapRouter = ISwapRouter(swapRouter_);

        developer = _msgSender();

        token.safeApprove(address(swapRouter), type(uint256).max);
    }

    function collect(uint256 amount) external override {
        require(target == _msgSender(), "FeeCollector: not the target");

        uint256 buybackAmount = amount * buybackFee / BASE_RATIO;

        token.safeTransferFrom(target, 0x000000000000000000000000000000000000dEaD, amount * burnFee / BASE_RATIO);
        token.safeTransferFrom(target, 0xb50785f60916733c9346fDaEA215044DA743Ab63, amount * partnerFee / BASE_RATIO);
        token.safeTransferFrom(target, developer, amount * developerFee / BASE_RATIO);
        token.safeTransferFrom(target, address(this), buybackAmount);

        _buyback(buybackAmount);

        emit CollectFee(address(token), target, amount);
    }

    function _buyback(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = buybackToken;

        uint256[] memory amounts = swapRouter.getAmountsOut(amount, path);
        swapRouter.swapExactTokensForTokens(amount, amounts[1], path, 0x000000000000000000000000000000000000dEaD, block.timestamp + 1200);
    }
}