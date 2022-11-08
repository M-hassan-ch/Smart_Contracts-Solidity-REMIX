// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC4907.sol";
contract RentableNft is ERC4907{
     //restrict owner to transfer token that is on rent ,,,,,,marked as rent
    struct TokenRecord{
        uint price;
        uint interval;
        address owner;
        bool isRented;
    }
    address public _owner;
    uint public _tokenId;
    //mapping(tokenId=>URI)
    mapping(uint=>string) _uri;
    //mapping(tokenId=>TokenMarkedFoRent)
    mapping(uint => TokenRecord) tokenDetails;
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
    }
    //checks whether a token id is valid or not
    modifier validTokenId(uint token_id){
        require(_exists(token_id), "Marketplace: Invalid token Id");
        require(ownerOf(token_id)!=address(0), "Marketplace: owner cannot be null address");
        _;
    }
    function mintNft(string memory uri) public{
        _mint(msg.sender, _tokenId);
        _uri[_tokenId] = uri;
        _tokenId++;
    }
    function markForRent(uint token_id, uint price ,uint interval) public{
        require(ownerOf(token_id) == msg.sender, "RentableNft: Not an owner of nft");
        require(tokenDetails[token_id].owner == address(0), "RentableNft: token already marked as rent");
        require(!tokenDetails[token_id].isRented, "RentableNft: token already on rent");
        require(price > 0, "RentableNft: Invalid price");
        require(interval > 0 , "RentableNft: Interval cannot be zero");
        //saving record
        tokenDetails[token_id] = TokenRecord(price, interval, msg.sender, false);
        _tokensForRent[msg.sender][_markedTokenLength[msg.sender]] = token_id;
        _markedTokenLength[msg.sender]++;
    }
    function borrowToken(uint token_id) public payable{
        require(tokenDetails[token_id].owner != address(0), "RentableNft: token is not for rent");
        require(!tokenDetails[token_id].isRented, "RentableNft: token already on rent");
        require(msg.value == tokenDetails[token_id].price, "RentableNft: Invalid price for borrowing");
        //
        uint64 expiry = uint64(block.timestamp + tokenDetails[token_id].interval);
        setUser(token_id, msg.sender, expiry);
        removeTokenMarkedAsRent(token_id);
        addTokenToOnRent(token_id, msg.sender);
        // transferring amount to  token owner
        payable(tokenDetails[token_id].owner).transfer(msg.value);
    }
    function viewTokenMarkedAsRent() public view returns(uint[] memory){
        uint totalTokens = _markedTokenLength[msg.sender];
        uint[] memory markedTokens = new uint[](totalTokens);
        for (uint i=0; i < totalTokens; i++)
        {
            markedTokens[i] = _tokensForRent[msg.sender][i];
        }
        return markedTokens;
    }
    function viewBorrowedTokens() public view returns(uint[] memory){
        uint totalTokens = _borrowedTokenLength[msg.sender];
        uint[] memory borrowedTokens = new uint[](totalTokens);
        for (uint i=0; i < totalTokens; i++)
        {
            borrowedTokens[i] = _tokensBorrowed[msg.sender][i];
        }
        return borrowedTokens;
    }
    function validate() public returns(uint){
        //return no. of removed token
    }
    function addTokenToOnRent(uint token_id, address user) internal{
        //updating token to "actually on rent"
        tokenDetails[token_id].isRented = true;
        _tokensBorrowed[user][_borrowedTokenLength[user]] = token_id;
        _borrowedTokenLength[user]++;
    }
    function removeTokenMarkedAsRent(uint token_id) internal{
        //removing token from "marked as rent"
        address tokenOwner = tokenDetails[token_id].owner;
        uint totalTokens = _markedTokenLength[tokenOwner];
        for (uint i=0; i < totalTokens; i++)
        {
            if (_tokensForRent[tokenOwner][i] == token_id){
                _tokensForRent[tokenOwner][i] = _tokensForRent[tokenOwner][totalTokens - 1];
                break;
            }
        }
        _markedTokenLength[tokenOwner]--;
    }
}