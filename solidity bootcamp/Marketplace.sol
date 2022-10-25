// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts@4.7.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";

contract Marketplace is ERC721, ERC721URIStorage, Ownable{
    
    struct MarketItem{
        bool forSale;
        uint actual_price;
        uint feeAmount;
        address payable actualOwner;
    }

    uint public __tokenId;
    uint public _feePercentage;
    mapping(uint=>MarketItem) public tokenForSale;

    constructor(uint fee) ERC721("MyToken", "MTK") {
        _feePercentage = fee;
    }

    //checks whether a token id is valid or not
    modifier validTokenId(uint token_id){
        require(ownerOf(token_id)!=address(0), "Marketplace: Invalid Token ID");
        _;
    }

    //any user can mint there nft
    function mintNft(string memory URI) public{
        _safeMint(msg.sender, __tokenId);
        _setTokenURI(__tokenId, URI);
        // setApprovalForAll(address(this), true);
        __tokenId++;
    }

    //user can mark his/her nft as available for sale or not
    function sellNft(uint token_id, uint amount) public validTokenId(token_id){
        require(amount>0, "Marketplace: Selling price is 0");
        require(msg.sender == ownerOf(token_id), "Marketplace: Not an owner of nft");
        address actualOwner = ownerOf(token_id);
        
        // giving marketplace permission to transfer token
        approve(address(this), __tokenId-1);
        //marking a token as available for sale
        tokenForSale[token_id].actualOwner = payable(actualOwner);
        tokenForSale[token_id].forSale = true;
        tokenForSale[token_id].actual_price = amount;
        tokenForSale[token_id].feeAmount = (_feePercentage * amount)/100;
    }
    
    function buyNft(uint token_id, address addressTo) payable public validTokenId(token_id){
        require(addressTo != address(0), "Marketplace: Transfer to null address");
        require(msg.sender != ownerOf(token_id), "Marketplace: Can't buy your own nft");
        require(addressTo != ownerOf(token_id), "Marketplace: Can't transfer nft to same address");
        require(tokenForSale[token_id].forSale, "Marketplace: Token is not for sale");
        require(msg.value == (tokenForSale[token_id].actual_price + tokenForSale[token_id].feeAmount) * 1 ether, "Marketplace: Invalid amount for buying a token");
        
        //getting actual owner of nft
        address payable actualOwner = tokenForSale[token_id].actualOwner;

        Marketplace _contract = Marketplace(address(this));
        // transfering ownership
        _contract.safeTransferFrom(actualOwner, msg.sender, token_id);
        // tranfering sale amount
        actualOwner.transfer(tokenForSale[token_id].actual_price * 1 ether);
        payable(owner()).transfer(tokenForSale[token_id].feeAmount * 1 ether);//
        // updating market Items
        tokenForSale[token_id] = MarketItem(false, 0,0, payable(address(0)));
    }

    //--- mising-- marking items not for sale --- redeem
    //--- problems facing while using floating points
    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // function test(uint amount, uint token_id) public view returns(uint){
    //     return (tokenForSale[token_id].actual_price + (tokenForSale[token_id].feeAmount/ 1 ether));
    // }
}