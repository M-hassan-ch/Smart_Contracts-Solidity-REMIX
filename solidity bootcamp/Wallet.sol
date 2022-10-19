// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Wallet{

    struct DepositeDetails{
        uint amount;
        bool isAllowanceSet;
        uint allowance;
    }

    address public owner;
    mapping(address=>DepositeDetails) transactions;
    mapping(address=>bool) guardians;
    uint no_ofTrueVotes;
    uint public temp;

    constructor(){
        owner = msg.sender;
    }

    function setAllowance(address account, uint amount) public{
        require(owner == msg.sender, "Not an owner. Request cancelled.........");
        transactions[account].isAllowanceSet = true;
        transactions[account].allowance = amount;
    }

    function getTemp() public view returns(uint,bool){
        return (transactions[msg.sender].allowance, transactions[msg.sender].isAllowanceSet);
    }

    function getBalance() public view returns(uint){
        return address(this).balance/1 ether;
    }

    receive() external payable{
        if (transactions[msg.sender].isAllowanceSet){
            require(transactions[msg.sender].allowance>= msg.value/ 1 ether, "transfer Limit exceeded");
        }
        transactions[msg.sender].amount+=msg.value;
        temp = msg.value;
    }

    //temp
    function transfer(address payable addressTo, uint amount) public {
        require(owner == msg.sender, "Not an owner. Request cancelled.........");
        addressTo.transfer(amount * 1 ether);

    }
}