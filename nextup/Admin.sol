// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "AthleteERC20.sol";

contract Admin is ERC20, Ownable{
    uint public _nxtTokenMaxSupply;
    uint public _nxtTokenSuppliedAmount;
    // uint public _pricePerNxtTokenInFiat;
    uint public _pricePerNxtToken;

// -------------------------- Managing Athlete --------------------------

    struct TokenDrop{
        uint timestamp;
        uint supply;
        uint price;
        bool isApplied;
    }

    struct AthleteERC20Details{
        uint pricePerToken; // Here price of AthleteERC20 token is in NextUp tokens
        address contractAddress;
        bool isDisabled;
        uint maxSupply;
        uint currentSupply;
    }

    uint _athleteId;

//  mapping(Athelete => Athlete ERC20 token details)
    mapping (uint => AthleteERC20Details) public _athleteERC20Detail;

    mapping(uint => TokenDrop[]) public _athleteTokenDrops;
    
    AthleteERC20 _athleteERC20Contract;
    Admin _self;

    constructor(uint maxSupply, uint priceInwei) ERC20("NextUp", "NXT") {
        require(maxSupply > 0, "Admin: Max supply should be greater than zero");
        require(priceInwei > 0, "Admin: Price of token should be greater than zero");
        
        _self = Admin(address(this));

        _nxtTokenMaxSupply = maxSupply;
        _pricePerNxtToken = priceInwei;

        // _pricePerNxtTokenInFiat = priceInFiat;
        // _mint(owner(), initialMint);
        // approve(address(this), initialMint);
    }

    function increaseNxtTokenMaxSupply(uint updatedSupply) public onlyOwner{
        require(updatedSupply > 0, "Admin: Updated supply should be greater than zero");
        _nxtTokenMaxSupply += updatedSupply;
    }

    function updateNxtTokenPrice(uint updatedPrice) public onlyOwner{
        _pricePerNxtToken = updatedPrice;
    }

    // -------------------- View Function ------------------------

    function getNxtTokenMaxSupply() public view onlyOwner returns(uint){
        return _nxtTokenMaxSupply;
    }

    function getNxtTokenPrice() public view onlyOwner returns(uint){
        return _pricePerNxtToken;
    }

    // function mintTokens(uint amount) public onlyOwner{
    //     require(amount>0, "Admin: Mint amount cant be zero");
    //     require(totalSupply() < _nxtTokenMaxSupply , "Admin: Max Supply limit reached");
    //     require(totalSupply() + amount <= _nxtTokenMaxSupply , "Admin: Can't mint tokens more than max supply");
    //     _mint(owner(), amount);
    //     approve(address(this), amount);
    // }

// -------------------------- User related functions --------------------------

//  In case, if customer is buying NextUp tokens in WEI
    function buyTokenInWei(uint amountToBuy) public payable
    {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(msg.value == (_pricePerNxtToken * amountToBuy), "UtilityToken: Insufficient amount to buy tokens");
        require(_nxtTokenSuppliedAmount < _nxtTokenMaxSupply, "Admin: Max supply limit reached");
        require(amountToBuy <= (_nxtTokenMaxSupply - _nxtTokenSuppliedAmount), "Admin: Max supply limit reached");

        _nxtTokenSuppliedAmount += amountToBuy;
        _mint(msg.sender, amountToBuy);
        // approve(address(this), amountToBuy);
    }

//  In case, if customer is buying NextUp tokens with USD (Fiat money)
    // function buyTokenInFiat(uint amountToBuy, address addressTo) public onlyOwner
    // {
    //     require(amountToBuy <= balanceOf(owner()), "Admin: Insufficient owner's balance");
    //     transferFrom(owner(), addressTo, amountToBuy);
    //     // approve(address(this), amountToBuy);
    // }

// -------------------------- Athlete related functions --------------------------

//   Delete an athlete profile is missing

    modifier validAthlete(uint athleteId){
        require(_athleteERC20Detail[athleteId].contractAddress != address(0), "Admin: Athlete account donot exists");
        _;
    }

//  Before calling this function admin has already deployed AthleteERC20 contract
//  ERC20 token name and symbol already had given during the deployement
//  Creating an athlete with drops. This function returns id of created athlete
    function createAthlete(AthleteERC20Details memory athleteDetails, TokenDrop[] memory tokenDrops)  public onlyOwner returns(uint){
        require(athleteDetails.contractAddress != address(0), "Admin: Athlete ERC20 contract cant be null");
        require(athleteDetails.maxSupply > 0, "Admin: Total supply should be greater than zero");
        require(validateDropDates(tokenDrops), "Admin: Invalid token drops");
        
        _athleteERC20Detail[_athleteId] =  athleteDetails;
        
        for (uint i=0; i<tokenDrops.length; i++){
            _athleteTokenDrops[_athleteId].push(tokenDrops[i]);
        }

        _athleteId++;

        return _athleteId-1;
    }

//  Admin call this function to update the price(In NXT tokens) of Athlete's ERC20 Token
    function updateAthleteTokenPrice(uint athleteId, uint price) public onlyOwner validAthlete(athleteId){
        _athleteERC20Detail[athleteId].pricePerToken = price;
    }

//  Admin call this function to increase the max supply of Athlete's ERC20 Token
    function updateAthleteTokenMaxSupply(uint athleteId, uint addSupply) public onlyOwner validAthlete(athleteId){
        require(addSupply > 1, "Admin: Amount of supply you wanted to increase should be greater than zero");
        _athleteERC20Detail[athleteId].maxSupply += addSupply;
    }

//  Admin call this function to increase the current supply of Athlete's ERC20 Token
    function updateAthleteTokenCurrentSupply(uint athleteId, uint newSupply) public onlyOwner validAthlete(athleteId){
        require(newSupply > 0, "Admin: Supply should be greater than zero");
        require(_athleteERC20Detail[athleteId].currentSupply + newSupply <= _athleteERC20Detail[athleteId].maxSupply, "Admin: Cant mint tokens greater than max supply");
        
        
        _athleteERC20Detail[athleteId].currentSupply += newSupply;
    }
    
//  Admin call this function to enable Athlete profile
    function enableAthleteProfile(uint athleteId) public onlyOwner validAthlete(athleteId){
        _athleteERC20Detail[athleteId].isDisabled = false;
    }

//  Admin call this function to disable Athlete profile
    function disableAthleteProfile(uint athleteId) public onlyOwner validAthlete(athleteId){
        _athleteERC20Detail[athleteId].isDisabled = true;
    }

//  Internal function to check whether invalid data exists in the token drops.
    function validateDropDates(TokenDrop[] memory drops) view internal onlyOwner returns(bool){

        for (uint i=0; i<drops.length; i++)
        {
            if ((drops[i].timestamp < block.timestamp) || drops[i].price<=0 || drops[i].supply<=0){
                return false;
            }
        }

        return true;
    }

    function getValidTokenDrop(uint athleteId) public onlyOwner validAthlete(athleteId) returns(TokenDrop memory){
        for (uint i=0; i<_athleteTokenDrops[athleteId].length;i++){    
            
            if (_athleteTokenDrops[athleteId][i].timestamp >= block.timestamp && !_athleteTokenDrops[athleteId][i].isApplied){
                
                _athleteTokenDrops[athleteId][i].isApplied = true;
                
                return _athleteTokenDrops[athleteId][i];
            }

        }

        return TokenDrop(0,0,0, true);

    }

//  Get all the token drops asociated with an athlete
    function getTokenDrops(uint athleteId) public view validAthlete(athleteId) returns(TokenDrop[] memory){
        return _athleteTokenDrops[athleteId];
    }

    // apply token drops

//
}