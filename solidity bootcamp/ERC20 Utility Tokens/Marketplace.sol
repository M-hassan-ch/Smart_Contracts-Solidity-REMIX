// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UtilityToken.sol";

contract Marketplace is ERC1155, Ownable {
    struct TokenDetails{
        uint amount;
        uint price;
        address owner;
    }

    uint public _tokenId;
    Marketplace _self;
    UtilityToken _utilityTokenContract;
    uint public _serviceFee;

//  mapping(tokenId => tokenURI)
    mapping(uint =>string) _uri;
//  mapping(tokenIdForSale => TokenForSaleDetails)
    mapping(uint => TokenDetails) _tokensForSale;

//  mapping(owner => Number of tokens on sale)
    mapping(address => uint) _noOfTokensForSale;
//  mapping(owner => arrLength of tokens for sale => (index => tokenId))
    mapping(address => mapping(uint => uint)) _tokensForSaleByOwner;

    constructor(uint serviceFee, address utilityToken) ERC1155("") {
        _serviceFee = serviceFee;
        _utilityTokenContract = UtilityToken(utilityToken);
        _self = Marketplace(address(this));
    }

    modifier validTokenOwner(uint token_id){
        require(balanceOf(msg.sender, token_id) > 0, "Marketplace: Sender dont have this token");
        _;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    ////////////////////////////////////////////////////

    function mintToken(
        string memory uri,
        uint256 amount
    ) public {
        _uri[_tokenId] = uri;
        _mint(msg.sender, _tokenId, amount, "");
        _tokenId++;
    }

    function sellToken(uint token_id, uint amount, uint price) public validTokenOwner(token_id){
        require(_tokensForSale[token_id].owner == address(0), "Marketplace: Token is already marked as ON sale");
        require(amount<= balanceOf(msg.sender, token_id), "Marketplace: Caller don't have enough tokens to sale");
        require(price > 0, "Marketplace: selling price should be be geater than zero");
        
         
        _tokensForSale[token_id].owner = msg.sender;
        _tokensForSale[token_id].amount = amount;
        _tokensForSale[token_id].price = price;
        
        _tokensForSaleByOwner[msg.sender][_noOfTokensForSale[msg.sender]] = token_id;
        _noOfTokensForSale[msg.sender] += 1;
         
        setApprovalForAll(address(this), true);
    }

    function buyToken(uint token_id) public{
        require(_tokensForSale[token_id].owner!=address(0), "Marketplace: Token is not for sale");
        require(_utilityTokenContract.checkBalance(msg.sender) == _tokensForSale[token_id].price, "Marketplace: Insufficient amount for borrowing");
        
        //missing 
        // transfer ownership
        _self.safeTransferFrom(_tokensForSale[token_id].owner, msg.sender, token_id, _tokensForSale[token_id].amount, "");
        // send token back to owner ERC20
        _utilityTokenContract.transferToken(msg.sender, _tokensForSale[token_id].owner, _tokensForSale[token_id].price);
        //deleting token id (marked as on sale)
        _noOfTokensForSale[_tokensForSale[token_id].owner] -=1;
        _tokensForSale[token_id].owner = address(0); //removing tokens that are marked as on sale
    }
}