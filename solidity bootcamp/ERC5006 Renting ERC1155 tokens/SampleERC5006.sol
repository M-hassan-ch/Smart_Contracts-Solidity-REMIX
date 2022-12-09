// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ERC5006.sol";

// ---------- MISSING ----------
//  ---Missing
//  transfer service fee, rent fee
//  Utility functions view Functions

contract SampleERC5006 is ERC5006, Ownable {
    
    struct TokenRecord{
        uint tokenId;
        uint price;
        uint copies;
        uint startTime;
        uint endTime;
        address lender;
        address rentedTo;
        uint recordId5006;
    }

    SampleERC5006 _self;
    uint public _tokenId;
    uint public _recId;
    
//  mapping(tokenId => tokenURI)
    mapping(uint =>string) public _uri;  //token URIs
//  mapping(recordId => TokenDetails)
    mapping(uint => TokenRecord) public _tokenRecords;  //General token records

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

// -------------------------- Implementation --------------------------

    constructor() ERC5006("", 10){
        _self = SampleERC5006(address(this));
    }
    
//  checks whether lender has enough tokens to mark for rent
    modifier validTokenOwner(address lender,uint token_id, uint copies){
        uint actualBalance = balanceOf(lender, token_id);
        // getting copies of token that lender has already marked for rent
        uint frozenBalance = _lenderFrozenBalance[lender][token_id];
        require((actualBalance >= frozenBalance ? actualBalance-frozenBalance : frozenBalance-actualBalance) >= copies, "Sample5006: Lender dont have enough token copies");
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
        // require(startTime + 15 >= block.timestamp , "Sample5006: Start time should be greater than current time");
        require(copies > 0, "Sample5006: Copies cannot be zero");
        
        //storing details about the tokken that are marked for rent
        _tokenRecords[_recId] = (TokenRecord(token_id, price, copies, startTime, endTime, msg.sender, address(0), 0));
        
        //storing details at the lender's end (adding record id in the array that contains recordsIds that lender marked for rent)
        _lenderMarkedRecordIds[msg.sender][token_id].push(_recId);

        // saving token id of record that has been marked for rent
        addToAvailableTokens(msg.sender, token_id);
        // freezing balance of lender
        _lenderFrozenBalance[msg.sender][token_id]+=copies;
        
        //  giving this contract permission to transfer tokens
        setApprovalForAll(address(this), true);
        
        _recId++;
    }

    function borrowToken(uint recId) payable public{
        require(_tokenRecords[recId].lender != address(0), "Sample5006: Invalid Record Id");
        require(_tokenRecords[recId].rentedTo == address(0), "Sample5006: Record already on rent Cant borrow");
        require(msg.value == _tokenRecords[recId].price, "Sample5006: Insufficient price");
        require(msg.sender != _tokenRecords[recId].lender, "Sample5006: Can't buy your own token");
        
        require(block.timestamp >= _tokenRecords[recId].startTime, "Sample5006: Record's starttime has NOT REACHED");
        require(block.timestamp < _tokenRecords[recId].endTime, "Sample5006: Record's endtime has been expired");

        uint userRecordId = _self.createUserRecord(_tokenRecords[recId].lender, msg.sender, _tokenRecords[recId].tokenId, uint64(_tokenRecords[recId].copies), uint64(_tokenRecords[recId].endTime));
                
        // save the data into the borrower's side (adding record id in the array that contains recordsIds of borrowed token)
        _userBorrowedRecordIds[msg.sender].push(recId);
        
        //remove recordId from the lender's marked record list (because it is now "actually on rent")
        removeMarkedRecId(recId, _tokenRecords[recId]);
        
        //Updating general record detail of the lended token
        _tokenRecords[recId].rentedTo = msg.sender;
        _tokenRecords[recId].recordId5006 = userRecordId;
        
        //adding recordId in the lender's actually on rent record list 
        _lenderOnRentRecordIds[_tokenRecords[recId].lender][_tokenRecords[recId].tokenId].push(recId);
    }

//  seller call this function to remove a record
    function removeFromRent(uint recId) public{
        require(_tokenRecords[recId].lender != address(0), "Sample5006: Invalid Record Id");
        require(_tokenRecords[recId].lender == msg.sender, "Sample5006: Not an valid owner of record");
        require(_tokenRecords[recId].rentedTo == address(0), "Sample5006: Token is on rent Cant remove record");

        removeMarkedRecId(recId, _tokenRecords[recId]);
        _lenderFrozenBalance[msg.sender][_tokenRecords[recId].tokenId] -= _tokenRecords[recId].copies;
        removeTokenRecord(recId);
    }

// lender call this function to validate his tokens (revert the ownership)
    function validateLendedTokens() public returns(uint) {
        // getting distinct tokenIDs, the lender marked as available for rent
        uint[] memory lenderMarkedtokenIds = _lenderAvailableTokens[msg.sender].values();
        uint recordExpired;

        // Iterating  on all available tokenIds
        for (uint i=0; i<lenderMarkedtokenIds.length; i++){
            
            //Iterating on all recordIds associated with a single tokenId
            // for(uint j=0; j<_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].length; j++){
            uint j=0;
            while (j < _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].length){
                // getting ERC5006 UserRecord from every TokenRecord
                UserRecord memory record = userRecordOf(_tokenRecords[_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j]].recordId5006);
                
                // check if the record expires
                if (record.owner == msg.sender && record.expiry < block.timestamp)
                {

                    // removing recordId from the borrowed recordIds list of Borrower
                    removeBorrowedRecId(_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j], record.user);
                    // deleting General tokenRecord details
                    removeTokenRecord(_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j]);
                    
                    // releasig lender's frozen balance
                    _lenderFrozenBalance[record.owner][record.tokenId]-=record.amount;
                    
                    // removing tokenId from the lenders available tokenIds list
                    deleteFromAvailableTokens(record.owner, record.tokenId);
                    
                    // removing expired recordId from lender's end (Lender OnRent recordIds list)
                    _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j] = _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].length - 1];
                    _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].pop();
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
    function removeBorrowedRecId(uint recId, address borrower) internal{
        
        for (uint index=0; index< _userBorrowedRecordIds[borrower].length; index++){
            // if the recId matched
            if (_userBorrowedRecordIds[borrower][index] == recId)
            {
                // Calling ERC5006 function to revert the ownership of expired record
                _self.deleteUserRecord(_tokenRecords[recId].recordId5006);
                // removing record Id from the borrower's array
                _userBorrowedRecordIds[borrower][index] = _userBorrowedRecordIds[borrower][_userBorrowedRecordIds[borrower].length - 1];
                _userBorrowedRecordIds[borrower].pop();
                break;
            }
        }
        
    }

    // it deletes a general tokenRecord
    function removeTokenRecord(uint recId) internal {
        
        delete _tokenRecords[recId];
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