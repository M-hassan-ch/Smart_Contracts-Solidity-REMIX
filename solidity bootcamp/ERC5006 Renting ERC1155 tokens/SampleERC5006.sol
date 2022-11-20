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
    uint _tokenId;
    uint _recId;
    
//  mapping(tokenId => tokenURI)
    mapping(uint =>string) _uri;  //token URIs
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

    constructor() ERC5006("", 3){
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
        // string memory uri,
        uint256 copies
    ) public {
        // _uri[_tokenId] = uri;
        _mint(msg.sender, _tokenId, copies, "");
        _tokenId++;
    }

//  lender will call this function to mark his tokens for rent
    function markForRent(uint token_id, uint copies, uint price, uint startTime, uint endTime) public validTokenOwner(msg.sender, token_id, copies){
        require(price > 0, "Sample5006: Renting price should be be geater than zero");
        require(startTime > 0 && endTime > 0 , "Sample5006: Timestamp cannot be zero");
        require(endTime >= block.timestamp , "Sample5006: End time should be greater than current time");
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
    
    function borrowToken(address lender, uint token_id, uint copies) payable public{
        require(_lenderFrozenBalance[lender][token_id]>= copies, "Sample5006: Lender did not marked enough token for rent");
        require(msg.sender != lender, "Sample5006: Can't buy your own token");
        
        uint[] memory recordIds = _lenderMarkedRecordIds[lender][token_id];
        bool recordFound;
        for (uint i=0; i<recordIds.length; i++){
            if (_tokenRecords[recordIds[i]].tokenId == token_id && _tokenRecords[recordIds[i]].lender == lender && _tokenRecords[recordIds[i]].copies == copies  && _tokenRecords[recordIds[i]].price == msg.value){ //&& _tokenRecords[recordIds[i]].startTime >= block.timestamp
                
                recordFound = true;
                // rent the token
                uint userRecordId = _self.createUserRecord(lender, msg.sender, token_id, uint64(copies), uint64(_tokenRecords[recordIds[i]].endTime));
                // save the data into the borrower's side
                //_userBorrowedRecordIds[msg.sender].push(userRecordId); old
                _userBorrowedRecordIds[msg.sender].push(recordIds[i]);
                //remove record from the lender's marked record list
                removeMarkedRecId(i, _tokenRecords[recordIds[i]]);
                _tokenRecords[recordIds[i]].rentedTo = msg.sender;
                _tokenRecords[recordIds[i]].recordId5006 = userRecordId;
                // _totalTokensOnRent[_tokenRecords[recordIds[i]].lender]++;
                _lenderOnRentRecordIds[lender][token_id].push(recordIds[i]);
                break;
            } 
        }
        require(recordFound, "Sample5006: Record not found");
    }
    
    // -------------------------- View (Utility) Functions --------------------------
    
    function getLenderFrozenBalance(uint token_id) public view returns(uint){
        return _lenderFrozenBalance[msg.sender][token_id];
    }
    function getTokenRecord(uint recId) public view returns(TokenRecord memory){
        require(recId < _recId, "SampleERC5006: Record dont exists");
        return _tokenRecords[recId];
    }
    function getLenderAvailableTokens() public view returns(uint[] memory){
        return _lenderAvailableTokens[msg.sender].values();
    }
    function getBorrowedRecordId() public view returns(uint[] memory){
        return _userBorrowedRecordIds[msg.sender];
    }
    function getMarkedRecordIds(uint token_id) public view returns(uint[] memory){
        
        uint[] memory markedRecordIds= new uint[](_lenderMarkedRecordIds[msg.sender][token_id].length);
        uint index = 0;
        
        for (uint i=0; i < _lenderMarkedRecordIds[msg.sender][token_id].length; i++){
            if (_tokenRecords[_lenderMarkedRecordIds[msg.sender][token_id][i]].rentedTo == address(0)){
                 markedRecordIds[index] = _lenderMarkedRecordIds[msg.sender][token_id][i];
                 index++;
            }
        }
        return markedRecordIds;
    }
    function getOnRentRecordIds(uint token_id) public view returns(uint[] memory){
        uint[] memory onRentRecordIds= new uint[](_lenderOnRentRecordIds[msg.sender][token_id].length);
        uint index = 0;
        
        for (uint i=0; i < _lenderOnRentRecordIds[msg.sender][token_id].length; i++){
            if (_tokenRecords[_lenderOnRentRecordIds[msg.sender][token_id][i]].rentedTo != address(0)){
                 onRentRecordIds[index] = _lenderOnRentRecordIds[msg.sender][token_id][i];
                 index++;
            }
        }
        return onRentRecordIds;
    }
    
    function validateLendedTokens() public returns(uint) {
        uint[] memory lenderMarkedtokenIds = _lenderAvailableTokens[msg.sender].values();
        uint recordExpired;
        for (uint i=0; i<lenderMarkedtokenIds.length; i++){
            // uint[] memory onRentRecordIds = _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]];
            for(uint j=0; j<_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].length; j++){
                UserRecord memory record = userRecordOf(_tokenRecords[_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j]].recordId5006);
                if (record.owner == msg.sender && record.expiry < block.timestamp)
                {
                    removeBorrowedRecId(_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j], record.user);
                    removeTokenRecord(_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j]);
                    
                    _lenderFrozenBalance[record.owner][record.tokenId]-=record.amount;
                    // _lenderAvailableTokens[record.owner].remove(record.tokenId);
                    deleteFromAvailableTokens(record.owner, record.tokenId);
                    _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][j] = _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]][_lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].length - 1];
                    _lenderOnRentRecordIds[msg.sender][lenderMarkedtokenIds[i]].pop();
                    recordExpired++;
                }
            }
        }
        return recordExpired;
    }
    // -------------------------- Internal Functions --------------------------
    function removeMarkedRecId(uint index, TokenRecord memory record) internal{
        _lenderMarkedRecordIds[record.lender][record.tokenId][index] = _lenderMarkedRecordIds[record.lender][record.tokenId][_lenderMarkedRecordIds[record.lender][record.tokenId].length - 1];
        _lenderMarkedRecordIds[record.lender][record.tokenId].pop();
    }
    function removeBorrowedRecId(uint recId, address borrower) internal{
        
        for (uint index=0; index< _userBorrowedRecordIds[borrower].length; index++){
            if (_userBorrowedRecordIds[borrower][index] == recId)
            {
                _self.deleteUserRecord(_tokenRecords[recId].recordId5006);
                _userBorrowedRecordIds[borrower][index] = _userBorrowedRecordIds[borrower][_userBorrowedRecordIds[borrower].length - 1];
                _userBorrowedRecordIds[borrower].pop();
                break;
            }
        }
        
    }
    function removeTokenRecord(uint recId) internal {
        /// i have some queries in this section
        // _tokenRecords[recId] = _tokenRecords[_recId - 1];
        // _recId--;

        delete _tokenRecords[recId];
    }
    function addToAvailableTokens(address lender, uint token_id) internal {
        if (!(_lenderFrozenBalance[lender][token_id]>0)){
            _lenderAvailableTokens[lender].add(token_id);
        }
    }
    function deleteFromAvailableTokens(address lender, uint token_id) internal{
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