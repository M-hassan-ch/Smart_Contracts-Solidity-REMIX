// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract SampleERC20{
    mapping(address=>uint) public balance;
    uint public totalCoin;
    address owner;
    
    constructor(){
        totalCoin=100;
        owner=msg.sender;
    }
    modifier onlyOwner(){
        require(msg.sender==owner, "Not an owner");
        _;
    }
    function transfer(address addressTo,uint amount) public onlyOwner returns(bool){
        balance[addressTo]+=amount;
        totalCoin-=amount;
        return true;
    }
}