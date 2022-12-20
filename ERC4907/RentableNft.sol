// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC4907.sol";

// ----------- MISSING -----------
//  Redeem.................... userOF(tokebnID)

contract RentableNft is ERC4907{
    
    struct TokenRecord{
        uint price;
        uint interval;
        address owner;
        bool isRented;
    }

    address public _owner;
    uint public _tokenId;
    RentableNft _self;
    
    //mapping(tokenId=>URI)
    mapping(uint=>string) _uri;
    //mapping(tokenId=>TokenMarkedFoRent)
    mapping(uint => TokenRecord) public _tokenDetails;
    
    // -------------------------- Marked as rent --------------------------
   
    //mapping(tokenOwner => total tokens marked as rent)
    mapping(address => uint) _markedTokenLength;
    //mapping(tokenOwner => (index => tokenId) )
    mapping(address => mapping(uint => uint)) _tokensForRent;
    
    // -------------------------- Actually on rent --------------------------
    
    //mapping(tokenOwner => total tokens marked as rent)
    mapping(address => uint) _borrowedTokenLength;

    //mapping(tokenOwner => (index => tokenId) )
    mapping(address => mapping(uint => uint)) _tokensBorrowed;
    
    constructor() ERC4907("test", "tkn"){
        _owner = msg.sender;
        _self = RentableNft(address(this));
    }

    //checks whether a token id is valid or not
    modifier validTokenId(uint token_id){
        require(_exists(token_id), "RentableNft: Invalid token Id");
        require(ownerOf(token_id)!=address(0), "RentableNft: owner cannot be null address");
        _;
    }

    function mintNft(string memory uri) public{
        _mint(msg.sender, _tokenId);
        _uri[_tokenId] = uri;
        _tokenId++;
    }

    //token owner call this function to make his token available for rent
    function markForRent(uint token_id, uint price ,uint interval) validTokenId(token_id) public{
        require(ownerOf(token_id) == msg.sender, "RentableNft: Not an owner of nft");
        require(!_tokenDetails[token_id].isRented, "RentableNft: token already on rent");
        require(_tokenDetails[token_id].owner == address(0), "RentableNft: token already marked as rent");
        require(price > 0, "RentableNft: Invalid price");
        require(interval > 0 , "RentableNft: Interval cannot be zero");
        
        //giving permission
        approve(address(this), token_id);
        
        //saving general token details
        _tokenDetails[token_id] = TokenRecord(price, interval, msg.sender, false);
        
        //keeping the record of token id that is marked as rent by the token owner
        _tokensForRent[msg.sender][_markedTokenLength[msg.sender]] = token_id;
        _markedTokenLength[msg.sender]++;
    }
    //Any user can call this function to borrow a speciffic token
    function borrowToken(uint token_id) validTokenId(token_id) public payable{
        require(_tokenDetails[token_id].owner != address(0), "RentableNft: token is not for rent");
        require(!_tokenDetails[token_id].isRented, "RentableNft: token already on rent");
        require(msg.sender != ownerOf(token_id), "RentableNft: Cannot borrow your own NFTs");
        require(msg.value == _tokenDetails[token_id].price, "RentableNft: Invalid price for borrowing");
        
        //settting expiry date for a token
        uint64 expiry = uint64(block.timestamp + _tokenDetails[token_id].interval);
        
        // setting a user for a speciffic token Id
        _self.setUser(token_id, msg.sender, expiry);
        
        // moving token from "Available for rent" to "Rented to a speciffic user"
        removeTokenMarkedAsRent(token_id);
        addTokenToOnRent(token_id, msg.sender);
        
        // transferring amount to  token owner
        payable(_tokenDetails[token_id].owner).transfer(msg.value);
    }
    // A token owner can call this function to view his tokens that are marked for rent
    function viewTokenMarkedAsRent() public view returns(uint[] memory){
        // getting total number of tokens that are marked for rent by the token owner
        uint totalTokens = _markedTokenLength[msg.sender];
        uint[] memory markedTokens = new uint[](totalTokens);
        
        for (uint i=0; i < totalTokens; i++)
        {
            // inserting token ids of marked token to an array
            markedTokens[i] = _tokensForRent[msg.sender][i];
        }

        return markedTokens;
    }
    // Borrower can call this function to view his borrowed tokens
    function viewBorrowedTokens() public view returns(uint[] memory){
        // getting total number of tokens that are borrowed by the user
        uint totalTokens = _borrowedTokenLength[msg.sender];
        uint[] memory borrowedTokens = new uint[](totalTokens);
        
        for (uint i=0; i < totalTokens; i++)
        {
            // inserting token ids of borrowed token to an array
            borrowedTokens[i] = _tokensBorrowed[msg.sender][i];
        }

        return borrowedTokens;
    }

    //code changed ---------- untested
    // it will remove expired tokens from borrowed token list of the caller
    function validate() public returns(uint){
        // getting total number of tokens that are borrowed by the user
        uint totalTokens = _borrowedTokenLength[msg.sender];
        uint tokensExpired;
        
        for (uint i=0; i < totalTokens; i++)
        {
            //getting token id of borrowed token
            uint tokenId = _tokensBorrowed[msg.sender][i];

            // checking whether token is expired
            if (userOf(tokenId) == address(0)){
                //removing expired token details
                _tokenDetails[tokenId].owner = address(0);
                _tokenDetails[tokenId].isRented = false;

                //removing token from the borrowed tokens list
                // if (i < totalTokens-1){
                //     _tokensBorrowed[msg.sender][i] = _tokensBorrowed[msg.sender][totalTokens-1];
                // }

                _tokensBorrowed[msg.sender][i] = _tokensBorrowed[msg.sender][totalTokens-1];
                _borrowedTokenLength[msg.sender]--;
                tokensExpired++;
            }
        }

        return tokensExpired;
    }
    function addTokenToOnRent(uint token_id, address user) internal{
        //updating token to "actually on rent"
        _tokenDetails[token_id].isRented = true;
        _tokensBorrowed[user][_borrowedTokenLength[user]] = token_id;
        _borrowedTokenLength[user]++;
    }
    function removeTokenMarkedAsRent(uint token_id) internal{
        //removing token from "marked as rent"
        //getting the token owner
        address tokenOwner = _tokenDetails[token_id].owner;
        
        // getting total number of tokens that are marked for rent by the token owner
        uint totalTokens = _markedTokenLength[tokenOwner];
        
        for (uint i=0; i < totalTokens; i++)
        {
            if (_tokensForRent[tokenOwner][i] == token_id){
                // removing the token from "marked for rent" token list
                _tokensForRent[tokenOwner][i] = _tokensForRent[tokenOwner][totalTokens - 1];
                break;
            }
        }

        _markedTokenLength[tokenOwner]--;
    }
    
    //code changed ---------- untested
    function transferToken(uint token_id, address to) public validTokenId(token_id){
        require(ownerOf(token_id) == msg.sender, "RentableNft: Caller is not an owner of NFT");
        require(to != ownerOf(token_id), "RentableNft: Cannot transfer NFT to yourself");
        require(to != address(0), "RentableNft: Cannot transfer NFT to null address");
        require(!_tokenDetails[token_id].isRented, "RentableNft: Token is currently on rent");
        
        // if token is marked for rent then remove it before transferring the token
        if (_tokenDetails[token_id].owner!=address(0)){
            removeTokenMarkedAsRent(token_id);
            _tokenDetails[token_id].owner = address(0);
        }

        safeTransferFrom(msg.sender, to, token_id);
    }
}