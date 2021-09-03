// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YYDSToken is ERC20 {
    address private constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    constructor() ERC20("YYDS Token", "YYDS") {
        _mint(_msgSender(), 1e34);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), BURN_ADDRESS, amount / 100);
        _transfer(_msgSender(), recipient, amount * 99 / 100);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, BURN_ADDRESS, amount / 100);
        _transfer(sender, recipient, amount * 99 / 100);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "YYDSToken: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }
}
