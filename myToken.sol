// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable{
    
    constructor (address initialOwner) 
    ERC20("Against", "AGNST")
    Ownable(initialOwner){
        _mint(msg.sender, 1000*10**decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }
}