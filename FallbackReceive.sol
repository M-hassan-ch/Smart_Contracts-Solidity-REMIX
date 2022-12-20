// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Receiver{
    string public func_call;
    receive() external payable{
        func_call="receive function called";
    }
    fallback() external payable{
        func_call="fallback function called";
    }
    function get() public view returns(uint){
        return address(this).balance/1 ether;
    }
}
contract Sender{
    receive() external payable{}

    function send(address receiver) public{
        (bool res, ) = receiver.call{value: 2 ether}("");
    }
    function get() public view returns(uint){
        return address(this).balance/1 ether;
    }
}