// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AthleteERC20 is ERC20, Ownable{

    constructor(string memory tokenName, string memory symbol) ERC20(tokenName, symbol) {    
    }

    function mintToken(uint amount, address addressTo) public onlyOwner{
        require(amount > 0, "AthleteERC20:: Token Amount should be greater than zero");
        require(addressTo != address(0), "AthleteERC20:: Minter address cant be null");
        _mint(addressTo, amount);
    }

    function transferTokens(address from, address to, uint amount) public onlyOwner{
        require(to!= address(0), "AthleteERC20:: Receiver address cant be null");
        require(from!= address(0), "AthleteERC20:: Sender address cant be null");
        require(amount > 0, "AthleteERC20:: Token Amount should be greater than zero");
        require(balanceOf(from) >= amount, "AthleteERC20:: Sender dont have sufficient tokens to transfer");

        transferFrom(from, to, amount);
    }

}