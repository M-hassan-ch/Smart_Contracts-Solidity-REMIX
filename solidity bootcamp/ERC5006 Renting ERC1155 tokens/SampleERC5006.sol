// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC5006.sol";
// ---------- ASSUMPTION ----------
//  Borrower will buy all copies of a token
contract SampleERC5006 is ERC5006, Ownable {
    
    event MarkedRent(address, uint);
    
    struct TokenDetails{
        uint amount;
        uint price;
        uint expiry;
        address owner;
    }

//  mapping(tokenId => tokenURI)
    mapping(uint =>string) _uri;

//  mapping(tokenIdOnRent => TokenOnRentDetails)
    mapping(uint => TokenDetails) _tokensMarkedOnRent;

//  mapping(ownnerAddress => tokensOnRent[])

//  mapping(owner => Number of tokens on rent)
    mapping(address => uint) _noOfTokensMarkedRented;

//  mapping(owner => arrLength of rented token ids => (index => tokenId))
    mapping(address => mapping(uint => uint)) _tokensRentedByOwner;

//  mapping(user => length of recordIds)
    mapping(address => uint) _noOfRecords;

//  mapping(user => arrLength of record ids => (index => recordId))
    mapping(address => mapping(uint => uint)) _recordOfUsers;
    
    SampleERC5006 _contract;
    uint public _serviceFee;
    uint public _tokenId;
    
    constructor(uint serviceFee) ERC5006("", 3){
        _serviceFee = serviceFee;
        _contract = SampleERC5006(address(this));
    }
    
    modifier validTokenOwner(uint token_id){
        require(balanceOf(msg.sender, token_id) > 0, "RentERC1155: Sender dont have this token");
        _;
    }
    
    function mintToken(
        string memory uri,
        uint256 amount
    ) public {
        _uri[_tokenId] = uri;
        _mint(msg.sender, _tokenId, amount, "");
        _tokenId++;
    }
    
    function rentToken(uint token_id, uint amount, uint price, uint timestamp) public validTokenOwner(token_id){
        require(_tokensMarkedOnRent[token_id].owner == address(0), "RentERC1155: Token is already marked as ON RENT");
        require(amount<= balanceOf(msg.sender, token_id), "RentERC1155: Caller don't have enough tokens to rent");
        require(price > 0, "RentERC1155: Renting price should be be geater than zero");
        // require(timestamp > block.timestamp, "RentERC1155: Renting time should be greater than current time");
        
        _tokensMarkedOnRent[token_id].owner = msg.sender;
        _tokensMarkedOnRent[token_id].amount = amount;
        _tokensMarkedOnRent[token_id].price = price;
        _tokensMarkedOnRent[token_id].expiry = timestamp;
       
        _tokensRentedByOwner[msg.sender][_noOfTokensMarkedRented[msg.sender]] = token_id;
        _noOfTokensMarkedRented[msg.sender] += 1;

        // SampleERC5006 _contract = new SampleERC5006(address(this));
        setApprovalForAll(address(this), true);
        emit MarkedRent(msg.sender, token_id);
    }
    
    
    function viewRentedTokens() public view returns(uint[] memory){
        uint[] memory totalTokensMarkedAsRent= new uint[](_noOfTokensMarkedRented[msg.sender]);

        for (uint i=0; i<totalTokensMarkedAsRent.length; i++)
        {
            totalTokensMarkedAsRent[i] = _tokensRentedByOwner[msg.sender][i];
        }
        return totalTokensMarkedAsRent;
    }
    
    function borrow(uint token_id) public payable{
        require(_tokensMarkedOnRent[token_id].owner!=address(0), "RentERC1155: Token is not for rent");
        require(msg.value == _tokensMarkedOnRent[token_id].price, "RentERC1155: Insufficient amount for borrowing");

        uint recordId = _contract.createUserRecord(_tokensMarkedOnRent[token_id].owner, msg.sender, token_id, uint64(_tokensMarkedOnRent[token_id].amount), uint64(_tokensMarkedOnRent[token_id].expiry + block.timestamp));

        //
        _recordOfUsers[msg.sender][ _noOfRecords[msg.sender]] = recordId;
        _noOfRecords[msg.sender]+=1;

        //deleting token id (marked as on rent) 
        _noOfTokensMarkedRented[_tokensMarkedOnRent[token_id].owner] -=1;
    }
    
    // validate time .......... decrease/delete record
    function getBorrowedTokens() public returns(uint[] memory){
        validateTokens(msg.sender);

        uint no_OfTokensBorrowed = _noOfRecords[msg.sender];
        require(no_OfTokensBorrowed>0, "RentERC1155: No token borrowed yet");
        uint[] memory tokensBorrowed = new uint[](no_OfTokensBorrowed);

        for (uint i=0; i< no_OfTokensBorrowed;i++){
            uint record_id = _recordOfUsers[msg.sender][i];
            tokensBorrowed[i] = userRecordOf(record_id).tokenId;
        }

        return tokensBorrowed;
    }

    function validateTokens(address user) internal {
        uint totalRecords = _noOfRecords[user];

        for (uint i=0; i< totalRecords;i++)
        {
            // gettig record id
            uint record_id = _recordOfUsers[user][i];
            UserRecord memory record = userRecordOf(record_id);
            // if token is expired
            if (record.expiry< block.timestamp)
            {
                // updating record history
                // _recordOfUsers[user][_noOfRecords[user] -1 ] = 0;
                _noOfRecords[user] -=1;
                _contract.deleteUserRecord(record_id);
            }
        }
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public {
        _burn(from, id, amount);
    }
}