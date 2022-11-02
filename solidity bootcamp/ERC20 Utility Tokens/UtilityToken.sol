// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// -----missing
//      -> buy tokens from a speciffic user

contract UtilityToken is ERC20, Ownable{
    uint public _maxSupply;
    uint public _pricePerToken;
    UtilityToken _contract;

    constructor(uint maxSupply, uint initialMint, uint price) ERC20("MyToken", "MTK") {
        require(initialMint>0, "UtilityToken: Initial token mint cant be zero");
        _contract = UtilityToken(address(this));
        _maxSupply = maxSupply;
        _pricePerToken = price;
        _mint(owner(), initialMint);
        approve(address(this), initialMint);
    }
    function mintTokens(uint amount) public onlyOwner{
        require(amount>0, "UtilityToken: Mint amount cant be zero");
        require(totalSupply() <= _maxSupply , "UtilityToken: Max Supply limit reached");
        require(totalSupply() + amount <= _maxSupply , "UtilityToken: Can't mint tokens more than max Limit");
        _mint(owner(), amount);
        approve(address(this), amount);
    }
    function increaseMaxSupply(uint amount) public onlyOwner{
        require(amount>0, "UtilityToken: Max mint amount cant be zero");
        _maxSupply += amount;
    }
    function buyToken(uint amountToBuy) public payable
    {
        require(msg.value == _pricePerToken * amountToBuy, "UtilityToken: Insufficient amount to buy tokens");
        require(amountToBuy <= balanceOf(owner()), "UtilityToken: Insufficient owner's balance");
        _contract.transferFrom(owner(), msg.sender, amountToBuy);
        approve(address(this), amountToBuy);
    }
    function transferToken(address from, address to , uint amount) public{
        _contract.transferFrom(from, to, amount);
    }
    function checkBalance(address account) public view returns(uint){
        return balanceOf(account);
    }

    function get() public pure returns(string memory){
        return "Hello world";
    }
}