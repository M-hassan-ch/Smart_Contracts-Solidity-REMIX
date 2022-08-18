// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract Lottery
{
    address public manager;
    address payable[] public participants;

    constructor()
    {
        manager = msg.sender;
    }

    receive() external payable
    {
        require(msg.value >= 1 ether);
        participants.push(payable(msg.sender));
    }

    function showBalance() public view returns(uint)
    {
        return(address(this).balance/1 ether);
    }

    function random() private view returns(uint)
    {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, participants.length)));
    }

    function declareWinner() public
    {
        require(participants.length>=3 && manager == msg.sender);
        uint index = random() % participants.length;
        participants[index].transfer(address(this).balance);
        participants = new address payable[](0);
    }
}