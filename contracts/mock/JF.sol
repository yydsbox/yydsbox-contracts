// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JF is ERC20 {

    constructor() ERC20("Jswap Finance Token", "JF") {
        _mint(_msgSender(), 1e34);
    }
}
