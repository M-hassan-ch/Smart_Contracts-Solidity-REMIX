// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "./ERC4907.sol";

//  to be Resolved
//  --> borrower stills resides in _users after lending time expires
//  --> 

contract RentableNft is ERC4907{
    //--- modifier missing token id is valid or not 
    address public owner;

    constructor(){
        owner = msg.sender;
    }

    //checks whether a token id is valid or not
    modifier validTokenId(uint token_id){
        require(_exists(token_id), "Marketplace: Invalid token Id");
        require(ownerOf(token_id)!=address(0), "Marketplace: owner cannot be null address");
        _;
    }

    function mintNft(string memory uri) public returns(uint){
        uint tokenId = safeMint(uri);
        return tokenId;
    }

    function rentNft(uint token_id, address addressTo, uint timestamp) public validTokenId(token_id){
        require(msg.sender == ownerOf(token_id), "RentableNft: Not an owner of nft");
        require(addressTo != address(0), "RentableNft: transfer to null address");
        require(userOf(token_id) == address(0), "RentableNft: nft is already on rent");
        // missing price for buying nft
        uint64 actualTime = uint64(block.timestamp + timestamp);

        setUser(token_id, addressTo, actualTime);
    }
    
}
