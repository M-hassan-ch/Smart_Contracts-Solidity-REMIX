// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/access/Ownable.sol";
import "AthleteERC20.sol";
import "NextUpERC20.sol";

contract Admin is Ownable{
// -------------------------- Managing Athlete --------------------------
    struct TokenDrop{
        uint timestamp;
        uint supply;
        uint price;
    }

    struct AthleteERC20Details{
        uint pricePerToken; // Here price of AthleteERC20 token is in NextUp tokens
        address contractAddress;
        bool isDisabled;
        uint maxSupply;
        uint suppliedAmount;
        uint availableForSale;
        bool countMaxSupplyAsAvailableTokens;
    }

    uint public _nxtTokenMaxSupply;
    uint public _nxtTokenSuppliedAmount;
    // uint public _pricePerNxtTokenInFiat;
    uint public _pricePerNxtToken;

    uint _athleteId;

    // AthleteERC20 _athleteERC20Contract;
    Admin _self;
    NextUpERC20 _nextUpERC20Contract;

//  mapping(Athelete => Athlete ERC20 token details)
    mapping (uint => AthleteERC20Details) public _athleteERC20Detail;
//  mapping(Athelete => Athlete token drops)
    mapping(uint => TokenDrop[]) public _athleteTokenDrops;

    constructor(uint maxSupply, uint priceInwei, address nextUpERC20Contract){
        require(maxSupply > 0, "Admin: Max supply should be greater than zero");
        require(priceInwei > 0, "Admin: Price of token should be greater than zero");
        require(nextUpERC20Contract != address(0), "Admin: Next-Up contract address is null");
        
        _self = Admin(address(this));
        _nextUpERC20Contract = NextUpERC20(nextUpERC20Contract);

        _nxtTokenMaxSupply = maxSupply;
        _pricePerNxtToken = priceInwei;

        // _pricePerNxtTokenInFiat = priceInFiat;
        // approve(address(this), initialMint);
    }

    // -------------------------- NextUp token related functions --------------------------

    function setNextUpERC20Contract(address nextUpERC20Contract) public onlyOwner{
        require(nextUpERC20Contract != address(0), "Admin: Next-Up contract address is null");
        _nextUpERC20Contract = NextUpERC20(nextUpERC20Contract);
    }

    function increaseNxtTokenMaxSupply(uint updatedSupply) public onlyOwner{
        require(updatedSupply > 0, "Admin: Updated supply should be greater than zero");
        _nxtTokenMaxSupply += updatedSupply;
    }

    function updateNxtTokenPrice(uint updatedPrice) public onlyOwner{
        _pricePerNxtToken = updatedPrice;
    }

    function getNxtTokenMaxSupply() public view onlyOwner returns(uint){
        return _nxtTokenMaxSupply;
    }

    function getNxtTokenPrice() public view onlyOwner returns(uint){
        return _pricePerNxtToken;
    }

// -------------------------- User related functions --------------------------

//  In case, if customer is buying NextUp tokens in WEI
    function buyNxtTokenInWei(uint amountToBuy) public payable
    {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(msg.value == (_pricePerNxtToken * amountToBuy), "UtilityToken: Insufficient amount to buy tokens");
        require(_nxtTokenSuppliedAmount < _nxtTokenMaxSupply, "Admin: Max supply limit reached");
        require(amountToBuy <= (_nxtTokenMaxSupply - _nxtTokenSuppliedAmount), "Admin: Admin dont have enough nextUp tokens");

        _nxtTokenSuppliedAmount += amountToBuy;
        _nextUpERC20Contract.mint(msg.sender, amountToBuy);
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

//  Delete an athlete profile is missing

    modifier isValidAthlete(uint athleteId){
        require(_athleteERC20Detail[athleteId].contractAddress != address(0), "Admin: Athlete account not found");
        _;
    }

    modifier isAthleteNotDisabled(uint athleteId){
        require(_athleteERC20Detail[athleteId].isDisabled == false, "Admin: Athlete account is disabled");
        _;
    }

//  Before calling this function admin has already deployed AthleteERC20 contract
//  ERC20 token name and symbol already had given during the deployement
//  Creating an athlete with drops(sorted array). This function returns id of created athlete
    function createAthlete(AthleteERC20Details memory athleteDetails, TokenDrop[] memory tokenDrops)  public onlyOwner returns(uint){
        require(athleteDetails.contractAddress != address(0), "Admin: Athlete ERC20 contract cant be null");
        require(athleteDetails.maxSupply > 0, "Admin: Total supply should be greater than zero");
        require(validateDropDates(tokenDrops), "Admin: Got an invalid token drop");
        
        _athleteId++;
        _athleteERC20Detail[_athleteId] =  athleteDetails;

        if (tokenDrops.length==0){
            // _athleteERC20Detail[_athleteId].availableForSale = _athleteERC20Detail[_athleteId].maxSupply;
            _athleteERC20Detail[_athleteId].countMaxSupplyAsAvailableTokens =true;
        }
        else{
            for (uint i=0; i<tokenDrops.length; i++){
                _athleteTokenDrops[_athleteId].push(tokenDrops[i]);
            }
            // availableForSale token will set when we run applyDrop() of athlete
        }

        return _athleteId;
    }

    function getAthleteAvailableForSaleTokens(uint athleteId) public isValidAthlete(athleteId) returns(uint){
        if (_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens){
            return (_athleteERC20Detail[athleteId].maxSupply - _athleteERC20Detail[athleteId].suppliedAmount);
        }
        else{
            return _athleteERC20Detail[athleteId].availableForSale;
        }
    }

    function addAthleteDrops(uint athleteId, TokenDrop[] memory tokenDrops) public onlyOwner isValidAthlete(athleteId){
        require(validateDropDates(tokenDrops), "Admin: Got an invalid token drop");

        _athleteERC20Detail[_athleteId].countMaxSupplyAsAvailableTokens =false;

        for (uint i=0; i<tokenDrops.length; i++){
            _athleteTokenDrops[_athleteId].push(tokenDrops[i]);
        }
    }

    function applyAthleteDrop(uint athleteId) public isValidAthlete(athleteId){
        require(_athleteTokenDrops[athleteId].length > 0, "Admin: Athlete token don't have drops");

        for (uint i=0; i<_athleteTokenDrops[athleteId].length; i++){
            if (block.timestamp >= _athleteTokenDrops[athleteId][i].timestamp){
                _athleteERC20Detail[athleteId].availableForSale += _athleteTokenDrops[athleteId][i].supply;
            }
        }
    }

    //  Internal function to check whether invalid data exists in the token drops.
    function validateDropDates(TokenDrop[] memory drops) view internal onlyOwner returns(bool){

        uint currentTime = block.timestamp;

        for (uint i=0; i<drops.length; i++)
        {
            if ((drops[i].timestamp < currentTime) || drops[i].price<=0 || drops[i].supply<=0){
                return false;
            }
        }

        return true;
    }

//  Admin call this function to update the price(In NXT tokens) of Athlete's ERC20 Token
    function updateAthleteTokenPrice(uint athleteId, uint price) public onlyOwner isValidAthlete(athleteId){
        _athleteERC20Detail[athleteId].pricePerToken = price;
    }

//  Admin call this function to increase the max supply of Athlete's ERC20 Token
    function increaseAthleteTokenMaxSupply(uint athleteId, uint addSupply) public onlyOwner isValidAthlete(athleteId){
        require(addSupply > 0, "Admin: Amount of supply you wanted to increase should be greater than zero");
        _athleteERC20Detail[athleteId].maxSupply += addSupply;
    }

    
//  Admin call this function to enable Athlete profile
    function enableAthleteProfile(uint athleteId) public onlyOwner isValidAthlete(athleteId){
        _athleteERC20Detail[athleteId].isDisabled = false;
    }

//  Admin call this function to disable Athlete profile
    function disableAthleteProfile(uint athleteId) public onlyOwner isValidAthlete(athleteId){
        _athleteERC20Detail[athleteId].isDisabled = true;
    }

    function getValidTokenDrop(uint athleteId) public view onlyOwner isValidAthlete(athleteId) returns(TokenDrop memory){
        for (uint i=0; i<_athleteTokenDrops[athleteId].length;i++){    
            
            if (_athleteTokenDrops[athleteId][i].timestamp >= block.timestamp && !_athleteTokenDrops[athleteId][i].isApplied){
                
                // _athleteTokenDrops[athleteId][i].isApplied = true;
                
                return _athleteTokenDrops[athleteId][i];
            }

        }

        return TokenDrop(0,0,0, true);

    }

//  Get all the token drops asociated with an athlete
    function getTokenDrops(uint athleteId) public view isValidAthlete(athleteId) returns(TokenDrop[] memory){
        return _athleteTokenDrops[athleteId];
    }

    // apply token drops

//
}