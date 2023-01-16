// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/access/Ownable.sol";
import "AthleteERC20.sol";
import "NextUp.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract Admin is Ownable, Pausable{
// -------------------------- Managing Athlete --------------------------
    struct Drop{
        uint timestamp;
        uint supply;
        uint price;
    }

    struct AthleteERC20Details{
        uint price; // Here price of AthleteERC20 token is in NextUp tokens
        address contractAddress;
        bool isDisabled;
        uint maxSupply;
        uint suppliedAmount;
        uint availableForSale;
        bool countMaxSupplyAsAvailableTokens;
    }

    uint public _nxtMaxSupply;
    uint public _nxtSuppliedAmount;
    // uint public _pricePerNxtTokenInFiat;
    uint public _nxtPrice;

    uint _athleteId;

    AthleteERC20 _athleteContract;
    Admin _self;
    NextUp _nextUpContract;

//  mapping(Athelete => Athlete ERC20 token details)
    mapping (uint => AthleteERC20Details) public _athleteERC20Detail;
//  mapping(Athelete => Athlete token drops)
    mapping(uint => Drop[]) public _athleteDrops;

    constructor(uint maxSupply, uint priceInwei, address nextUpERC20Contract){
        require(maxSupply > 0, "Admin: Max supply should be greater than zero");
        require(priceInwei > 0, "Admin: Price of token should be greater than zero");
        require(nextUpERC20Contract != address(0), "Admin: Next-Up contract address is null");
        
        _self = Admin(address(this));
        _nextUpContract = NextUp(nextUpERC20Contract);

        _nxtMaxSupply = maxSupply;
        _nxtPrice = priceInwei;

        // _pricePerNxtTokenInFiat = priceInFiat;
        // approve(address(this), initialMint);
    }


    modifier isValidAthlete(uint athleteId){
        require(_athleteERC20Detail[athleteId].contractAddress != address(0), "Admin: Athlete account not found");
        _;
    }

    modifier isAthleteNotDisabled(uint athleteId){
        require(_athleteERC20Detail[athleteId].isDisabled == false, "Admin: Athlete account is disabled");
        _;
    }

    function setNextUpERC20Contract(address nextUpERC20Contract) public onlyOwner{
        require(nextUpERC20Contract != address(0), "Admin: Next-Up contract address is null");
        _nextUpContract = NextUp(nextUpERC20Contract);
    }

    function increaseNxtTokenMaxSupply(uint updatedSupply) public onlyOwner{
        require(updatedSupply > 0, "Admin: Updated supply should be greater than zero");
        _nxtMaxSupply += updatedSupply;
    }

    function updateNxtTokenPrice(uint updatedPrice) public onlyOwner{
        _nxtPrice = updatedPrice;
    }


// -------------------------- User related functions --------------------------

//  In case, if customer is buying NextUp tokens in WEI
    function buyNxtTokenInWei(uint amountToBuy) public payable
    {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(msg.value == (_nxtPrice * amountToBuy), "Admin: Insufficient balance to buy NXT tokens");
        require(_nxtSuppliedAmount < _nxtMaxSupply, "Admin: Max supply limit reached");
        require(amountToBuy <= (_nxtMaxSupply - _nxtSuppliedAmount), "Admin: Admin dont have enough nextUp tokens");

        _nxtSuppliedAmount += amountToBuy;
        _nextUpContract.mint(msg.sender, amountToBuy);
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


//  Before calling this function admin has already deployed AthleteERC20 contract
//  ERC20 token name and symbol already had given during the deployement
//  Creating an athlete with drops(sorted array). This function returns id of created athlete


    function createAthlete(AthleteERC20Details memory athleteDetails, Drop[] memory tokenDrops)  public onlyOwner returns(uint){
        require(isValidDrop(tokenDrops), "Admin: Got an invalid token drop");
        require(isValidAthleteDetails(athleteDetails), "Admin: Inavalid athlete details");

        _athleteId++;
        _athleteERC20Detail[_athleteId] =  athleteDetails;

        if (tokenDrops.length==0){
            // _athleteERC20Detail[_athleteId].availableForSale = _athleteERC20Detail[_athleteId].maxSupply;
            _athleteERC20Detail[_athleteId].countMaxSupplyAsAvailableTokens =true;
        }
        else{
            for (uint i=0; i<tokenDrops.length; i++){
                _athleteDrops[_athleteId].push(tokenDrops[i]);
            }
            // availableForSale token will set when we run applyDrop() of athlete
        }

        return _athleteId;
    }

    function addAthleteDrops(uint athleteId, Drop[] memory tokenDrops) public onlyOwner isValidAthlete(athleteId){
        require(isValidDrop(tokenDrops), "Admin: Got an invalid token drop");

        _athleteERC20Detail[_athleteId].countMaxSupplyAsAvailableTokens =false;

        for (uint i=0; i<tokenDrops.length; i++){
            _athleteDrops[_athleteId].push(tokenDrops[i]);
        }
    }

    function applyAthleteDrop(uint athleteId) public isValidAthlete(athleteId) returns (bool, Drop memory){
        require(_athleteDrops[athleteId].length > 0, "Admin: Athlete token don't have drops");
        Drop memory drop;

        for (uint i=0; i<_athleteDrops[athleteId].length; i++){
            if (block.timestamp >= _athleteDrops[athleteId][i].timestamp){
                _athleteERC20Detail[athleteId].availableForSale += _athleteDrops[athleteId][i].supply;
                drop = _athleteDrops[athleteId][i];
                deleteTokenDrop(athleteId, i);
                return (true, drop);
            }
        }

        return (false, drop);
    }


    function buyAthleteTokens(uint athleteId, uint amountToBuy) public isValidAthlete(athleteId) isAthleteNotDisabled(athleteId) {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(_athleteERC20Detail[athleteId].suppliedAmount < _athleteERC20Detail[athleteId].maxSupply, "Admin: Max supply limit reached");
        require(amountToBuy <= getAthleteAvailableForSaleTokens(athleteId), "Admin: Athlete Dont have enough available tokens");
        require(getUserNxtBalance() == (_athleteERC20Detail[athleteId].price * amountToBuy), "Admin: Insufficient NXT Tokens to buy athlete tokens");
        // require(amountToBuy <= (_nxtMaxSupply - _nxtSuppliedAmount), "Admin: Admin dont have enough nextUp tokens");


        _athleteERC20Detail[athleteId].suppliedAmount += amountToBuy;

        if (!_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens){
            _athleteERC20Detail[athleteId].availableForSale -= amountToBuy;
        }
    }

//  Admin call this function to update the price(In NXT tokens) of Athlete's ERC20 Token
    function updateAthleteTokenPrice(uint athleteId, uint price) public onlyOwner isValidAthlete(athleteId){
        _athleteERC20Detail[athleteId].price = price;
    }

//  Admin call this function to increase the max supply of Athlete's ERC20 Token
    function increaseAthleteTokenMaxSupply(uint athleteId, uint addSupply) public onlyOwner isValidAthlete(athleteId){
        require(addSupply > 0, "Admin: Amount of supply you wanted to increase should be greater than zero");
        _athleteERC20Detail[athleteId].maxSupply += addSupply;
    }

    function updateAthleteStatus(bool status, uint athleteId) public onlyOwner isValidAthlete(athleteId){
        _athleteERC20Detail[athleteId].isDisabled = status;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

//          --------------------- View Functions -----------------------
    
    function getAthleteAvailableForSaleTokens(uint athleteId) public view isValidAthlete(athleteId) returns(uint){
        if (_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens){
            return (_athleteERC20Detail[athleteId].maxSupply - _athleteERC20Detail[athleteId].suppliedAmount);
        }
        else{
            return _athleteERC20Detail[athleteId].availableForSale;
        }
    }

    //  Get all the token drops asociated with an athlete
    function getTokenDrops(uint athleteId) public view isValidAthlete(athleteId) returns(Drop[] memory){
        return _athleteDrops[athleteId];
    }

    function getUserNxtBalance() public view returns(uint){
        return _nextUpContract.balanceOf(msg.sender);
    }

//          --------------------- Internal Functions -----------------------

    function isValidDrop(Drop[] memory drops) view internal onlyOwner returns(bool){

        uint currentTime = block.timestamp;

        for (uint i=0; i<drops.length; i++)
        {
            if ((drops[i].timestamp < currentTime) || drops[i].price<=0 || drops[i].supply<=0){
                return false;
            }
        }

        return true;
    }

    function isValidAthleteDetails(AthleteERC20Details memory athleteDetails) internal pure returns(bool) {
        if (!(athleteDetails.price > 0 || athleteDetails.contractAddress != address(0) || athleteDetails.isDisabled == false || athleteDetails.maxSupply > 0 || athleteDetails.suppliedAmount == 0 || athleteDetails.availableForSale == 0 || athleteDetails.countMaxSupplyAsAvailableTokens == false)){
            return false;
        }
        return true;
    }

    function deleteTokenDrop(uint athleteId, uint index) internal{
       _athleteDrops[athleteId][index] = _athleteDrops[athleteId][_athleteDrops[athleteId].length -1];
       _athleteDrops[athleteId].pop();
    }

}