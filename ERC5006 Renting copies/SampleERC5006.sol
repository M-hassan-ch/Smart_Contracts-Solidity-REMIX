

// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ERC5006.sol";

// ---------- MISSING ----------
//  transfer service fee, rent fee

contract SampleERC5006 is ERC5006, Ownable {
    
    struct TokenRecord{
        uint tokenId;
        uint price;
        uint copies;
        uint startTime;
        uint endTime;
        address lender;
    }

    struct BorrowedRecord{
        uint markedRecId;
        address rentedTo;
        uint copiesBorrowed;
        uint recordId5006;
    }

    SampleERC5006 _self;

    uint public _tokenId;
    uint public _markedRecId;
    uint public _onRentRecId;
    
//  mapping(tokenId => tokenURI)
    mapping(uint =>string) public _uri;  //token URIs

//  mapping(recordId => markedTokenDetails)
    mapping(uint => TokenRecord) public _markedTokenRecord;  //token record marked for rent
//  mapping(recordId => onRentTokenDetails)
    mapping(uint => BorrowedRecord) public _onRentTokenRecord;  //token record on rent

// -------------------------- Marked as rent --------------------------

//  mapping(lender => (tokenId => recIDs[]))
    mapping(address => mapping(uint => uint[])) _lenderMarkedRecordIds;
//  mapping(lender => (tokenId => recIDs[]))
    mapping(address => mapping(uint => uint[])) _lenderOnRentRecordIds;
//  mapping(lender => (tokenId => balance))
    mapping(address => mapping(uint => uint)) _lenderFrozenBalance;  //This stores data about total copies of token that lender has given this contract for renting
    
//  This will store all the distinct tokenIds of lender that he gave this contract for renting
//  This can help us in getting recordIds associated with a single token id (a lender can create multiple package of a single token)    
    using EnumerableSet for EnumerableSet.UintSet;
//  mapping(lender => tokenIds[])
    mapping(address => EnumerableSet.UintSet) _lenderAvailableTokens;

// -------------------------- Actually on rent --------------------------

//  mapping(user => array containing record ids of borrowed tokens)
    mapping(address => uint[]) _userBorrowedRecordIds;

    // -------------------------- Beta try --------------------------

//  mapping(markedRecId => mapping(borrower => mapping(tokenId => copiesBorrowed)))
    // mapping(uint => mapping(address => mapping(uint => uint))) _userBorrowedRecordIds;

// -------------------------- Implementation --------------------------

    constructor() ERC5006("", 10){
        _self = SampleERC5006(address(this));
    }
    
//  checks whether lender has enough tokens to mark for rent
    modifier validTokenOwner(address lender,uint token_id, uint copies){
        uint actualBalance = balanceOf(lender, token_id);
        uint lenderFrozenBalance = _lenderFrozenBalance[lender][token_id];

        if (lenderFrozenBalance == 0){
            require(copies <= actualBalance, "Sample5006: Lender dont have enough token copies");    
        }
        else if (lenderFrozenBalance > 0 && frozenBalanceOf(lender, token_id) == 0){
            require(copies <= (actualBalance >= lenderFrozenBalance ? actualBalance-lenderFrozenBalance : lenderFrozenBalance-actualBalance), "Sample5006: Lender dont have enough token copies. Remove some marked records and try again");
        }
        else if (lenderFrozenBalance > 0 && frozenBalanceOf(lender, token_id) > 0)
        {
            require(copies <= actualBalance, "Sample5006: Lender dont have enough token copies. Redeem some record and try again");
        }
        _;
    }
    
    function mintToken(
        string memory uri,
        uint256 copies
    ) public {
        _uri[_tokenId] = uri;
        _mint(msg.sender, _tokenId, copies, "");
        _tokenId++;
    }

//  lender will call this function to mark his tokens for rent
    function markForRent(uint token_id, uint copies, uint price, uint startTime, uint endTime) public validTokenOwner(msg.sender, token_id, copies){
        require(price > 0, "Sample5006: Renting price should be be geater than zero");
        require(startTime > 0 && endTime > 0 , "Sample5006: Timestamps cannot be zero");
        
        require(startTime < endTime, "Sample5006: Start time should be less than end time");
        require(endTime > block.timestamp , "Sample5006: End time should be greater than current time");
        // require(startTime  >= block.timestamp , "Sample5006: Start time should be greater than current time");
        require(copies > 0, "Sample5006: Copies cannot be zero");
        
        //storing details about the tokken that are marked for rent
        _markedTokenRecord[_markedRecId] = (TokenRecord(token_id, price, copies, startTime, endTime, msg.sender));
        
        //storing details at the lender's end (adding record id in the array that contains recordsIds that lender marked for rent)
        _lenderMarkedRecordIds[msg.sender][token_id].push(_markedRecId);

        // saving token id of record that has been marked for rent
        addToAvailableTokens(msg.sender, token_id);
        // freezing balance of lender
        _lenderFrozenBalance[msg.sender][token_id]+=copies;
        
        //  giving this contract permission to transfer tokens
        setApprovalForAll(address(this), true);
        
        _markedRecId++;
    }

    function borrowToken(uint markedRecId, uint copies) payable public{
        require(copies > 0, "Sample5006: Copies you want to borrow should be greater than zero");
        require(_markedTokenRecord[markedRecId].lender != address(0), "Sample5006: Invalid Record Id");
        require(_markedTokenRecord[markedRecId].copies > 0, "Sample5006: All copies alrady sold");
        require(copies <= _markedTokenRecord[markedRecId].copies, "Sample5006: Record dont have enough token copies");
        require(msg.value == (_markedTokenRecord[markedRecId].price * copies) , "Sample5006: Insufficient price");
        require(msg.sender != _markedTokenRecord[markedRecId].lender, "Sample5006: Can't buy your own token");
        
        require(block.timestamp >= _markedTokenRecord[markedRecId].startTime, "Sample5006: Record's starttime has NOT REACHED");
        require(block.timestamp < _markedTokenRecord[markedRecId].endTime, "Sample5006: Record's endtime has been expired");

        uint userRecordId5006 = _self.createUserRecord(_markedTokenRecord[markedRecId].lender, msg.sender, _markedTokenRecord[markedRecId].tokenId, uint64(copies), uint64(_markedTokenRecord[markedRecId].endTime));
        
        _onRentTokenRecord[_onRentRecId] = BorrowedRecord(markedRecId, msg.sender, copies, userRecordId5006);
        
        // save the data into the borrower's side (adding record id in the array that contains recordsIds of borrowed token)
        _userBorrowedRecordIds[msg.sender].push(_onRentRecId);
        
        //remove recordId from the lender's marked record list (because it is now "actually on rent")
        // removeMarkedRecId(markedRecId, _markedTokenRecord[markedRecId]);
        
        //Updating general record detail of the lended token
        _markedTokenRecord[markedRecId].copies -= copies;
        // _markedTokenRecord[markedRecId].rentedTo = msg.sender;
        // _markedTokenRecord[markedRecId].recordId5006 = userRecordId;
        
        //adding recordId in the lender's actually on rent record list 
        _lenderOnRentRecordIds[_markedTokenRecord[markedRecId].lender][_markedTokenRecord[markedRecId].tokenId].push(_onRentRecId);

        _onRentRecId++;
    }

//  seller call this function to remove a record
    function removeFromRent(uint recId) public{
        require(_markedTokenRecord[recId].lender != address(0), "Sample5006: Invalid Record Id");
        require(_markedTokenRecord[recId].lender == msg.sender, "Sample5006: Not an valid owner of record");
        require(_lenderOnRentRecordIds[msg.sender][_markedTokenRecord[recId].tokenId].length == 0, "Sample5006: Record is on rent Cant remove record");

        removeMarkedRecId(recId, _markedTokenRecord[recId]);
        _lenderFrozenBalance[msg.sender][_markedTokenRecord[recId].tokenId] -= _markedTokenRecord[recId].copies;
        deleteFromAvailableTokens(msg.sender, _markedTokenRecord[recId].tokenId);
        removeTokenRecord(recId);
    }

// lender call this function to validate his tokens (revert the ownership)
    function validateLendedTokens() public returns(uint) {
        // getting distinct tokenIDs, the lender marked as available for rent
        uint[] memory lenderAvailableTokens = _lenderAvailableTokens[msg.sender].values();
        uint recordExpired;

        // Iterating  on all available tokenIds
        for (uint i=0; i<lenderAvailableTokens.length; i++){
            
            uint j = 0;
            while (j < _lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]].length){
                // getting ERC5006 UserRecord from every TokenRecord
                UserRecord memory record = userRecordOf(_onRentTokenRecord[_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][j]].recordId5006);
                
                // check if the record expires
                if (record.owner == msg.sender && record.expiry < block.timestamp)
                {
                    // removing recordId from the borrowed recordIds list of Borrower
                    removeBorrowedRecId(_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][j], record.user);

                    // releasig lender's frozen balance
                    _lenderFrozenBalance[record.owner][record.tokenId]-=record.amount;
                    
                    // removing tokenId from the lenders available tokenIds list
                    deleteFromAvailableTokens(record.owner, record.tokenId);
                    
                    // deleting General tokenRecord details
                    // if (_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]].length == 1){
                    //     uint markedRecId = _onRentTokenRecord[_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][j]].markedRecId;
                    //     removeTokenRecord(markedRecId);
                    // }
                    
                    // deleting Onrent General general detail record
                    delete _onRentTokenRecord[_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][j]];

                    // removing expired recordId from lender's end (Lender OnRent recordIds list)
                    _lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][j] = _lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]][_lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]].length - 1];
                    _lenderOnRentRecordIds[msg.sender][lenderAvailableTokens[i]].pop();

                    recordExpired++;
                }
                else{
                    j+=1;
                }
            }
        }
        return recordExpired;
    }

//  temp Func
    function returnAmount() public{
        payable(msg.sender).transfer(address(this).balance);
    }
    

    // -------------------------- View (Utility) Functions --------------------------
    
    // lender call this function to view his total copies of token that is made available for rent
    function getLenderFrozenBalance(uint token_id) public view returns(uint){
        return _lenderFrozenBalance[msg.sender][token_id];
    }

    // lender call this function to view his distinct tokenIds that is made available for rent
    function getLenderAvailableTokens() public view returns(uint[] memory){
        return _lenderAvailableTokens[msg.sender].values();
    }

    //Borrower call this function to view the recordIds he borrowed
    function getBorrowedRecordId() public view returns(uint[] memory){
        return _userBorrowedRecordIds[msg.sender];
    }

    // lender call this function to view his recordIds of a speciffic token that is marked as rent
    function getMarkedRecordIds(uint token_id) public view returns(uint[] memory){
        
        return _lenderMarkedRecordIds[msg.sender][token_id];
    }

    // lender call this function to view his recordIds of a speciffic token that is actually on rent
    function getOnRentRecordIds(uint token_id) public view returns(uint[] memory){
        return _lenderOnRentRecordIds[msg.sender][token_id];
    }
    
    // -------------------------- Internal Functions --------------------------
    


//  removing recordId from lender's end (Lender Marked for rent recordIds list)
    function removeMarkedRecId(uint recId, TokenRecord memory record) internal{
        for (uint index=0;index<_lenderMarkedRecordIds[record.lender][record.tokenId].length;index++){
            
            if (_lenderMarkedRecordIds[record.lender][record.tokenId][index]==recId){
                _lenderMarkedRecordIds[record.lender][record.tokenId][index] = _lenderMarkedRecordIds[record.lender][record.tokenId][_lenderMarkedRecordIds[record.lender][record.tokenId].length - 1];
                _lenderMarkedRecordIds[record.lender][record.tokenId].pop();
                break;
            }

        }
    }

    // this function is used to delete a borrowed recordId from borrower's end
    function removeBorrowedRecId(uint onRentrecId, address borrower) internal{
        
        for (uint index=0; index< _userBorrowedRecordIds[borrower].length; index++){
            // if the recId matched
            if (_userBorrowedRecordIds[borrower][index] == onRentrecId)
            {
                // Calling ERC5006 function to revert the ownership of expired record
                _self.deleteUserRecord(_onRentTokenRecord[onRentrecId].recordId5006);
                // removing record Id from the borrower's array
                _userBorrowedRecordIds[borrower][index] = _userBorrowedRecordIds[borrower][_userBorrowedRecordIds[borrower].length - 1];
                _userBorrowedRecordIds[borrower].pop();
                break;
            }
        }
        
    }

    // it deletes a general tokenRecord
    function removeTokenRecord(uint recId) internal {
        delete _markedTokenRecord[recId];
    }


    function addToAvailableTokens(address lender, uint token_id) internal {
        //if the lender does not have any copy of a token that is marked for rent then it to the available token list
        if (!(_lenderFrozenBalance[lender][token_id]>0)){
            _lenderAvailableTokens[lender].add(token_id);
        }
    }


    function deleteFromAvailableTokens(address lender, uint token_id) internal{
        // if the lender has no more copies of a token that is amrked as rent or onRent then delete that token Id
        if (_lenderFrozenBalance[lender][token_id] == 0){
            _lenderAvailableTokens[lender].remove(token_id);
        }
    }
    
    function burn(
        address from,
        uint256 id,
        uint256 copies
    ) public {
        _burn(from, id, copies);
    }
}
