// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

// min-contributers >= 2
// gathered funding > 3 ethers && within due date 
// 50% contributer's votes are required to charity the total funding
// Manager can
//  ->create a request
//  ->request to approve the charity request

struct Contributer
{
    address payable contributer;
    uint totalContribution;
    bool hasVoted;
    bool approveRequest;
}

struct Event
{
    uint duration;
    uint minContribution;
    uint goalAmount;
    uint currentContrib;
}

// 20,1,2,  test-case, constructor parameter
contract CrowdFunding
{
    address manager;
    Contributer[] contributers;
    Event _event;
    string requestDescription;
    Contributer[] emptyArray;

    constructor(uint _duration,  uint _minContribution, uint _goalAmount)
    {
        _goalAmount*=(10**18);
        _minContribution*=(10**18);
        manager = msg.sender;
        _event = Event({duration:(block.timestamp+_duration), minContribution: _minContribution, goalAmount: _goalAmount, currentContrib:0});
    }

    function findUser(address sender) private view returns(int)
    {
        for (uint i=0;i<contributers.length;i++)
        {
            if (contributers[i].contributer == sender)
            {
                return int(i);
            }
        }
        return -1;
    }

    function getTotalContributers() view public returns (uint)
    {
        return contributers.length;
    }

    function sendMoney() public payable
    {
        require(msg.value>=_event.minContribution, "amount lesser than required amount");
        require(block.timestamp<_event.duration, "Due date is passed");

        int index = findUser(msg.sender);

        if (index>=0)
        {
            contributers[uint(index)].totalContribution += msg.value;
        }
        else
        {
            contributers.push(Contributer({contributer:payable(msg.sender),totalContribution:msg.value,hasVoted:false,approveRequest:false}));
        }
        _event.currentContrib+=msg.value;
    }

    function getBalance() view public returns(uint)
    {
        return _event.currentContrib/1 ether;
    }
 
    function refund() public
    {
        int index = findUser(msg.sender);
        require(index>=0,"You have to be a cotributer first");
        _event.currentContrib-=contributers[uint(index)].totalContribution;
        contributers[uint(index)].contributer.transfer(contributers[uint(index)].totalContribution);
        contributers[uint(index)] = contributers[contributers.length-1];
        contributers.pop();
    }

    function generateRequest(string memory desc) public
    {
        require(manager==msg.sender, "Only manager can generate request");
        //require(_event.currentContrib>=goalAmount, "Goal amount is not acheived");
        requestDescription = desc;
    }

    function getReqDescription() public view returns(string memory)
    {
        return requestDescription;
    }

    function voteForRequest(string memory decision) public returns(string memory)
    {
        require(manager!=msg.sender, "Manager cannot vote");
        int index = findUser(msg.sender);
        require(index>=0,"You must have to contribute first");
        require(!contributers[uint(index)].hasVoted,"You have already voted");
        if (keccak256(bytes(decision)) == keccak256(bytes("1")))
        {
            contributers[uint(index)].approveRequest=true;   
        }
        else
        {
            contributers[uint(index)].approveRequest=false;
        }
        contributers[uint(index)].hasVoted=true;
        return "Your vote is recorded";
    }

    function giveCharity(address payable user) public
    {
        uint yesVotes;
        uint totalVotedUsers;
        
        for (uint i=0;i<contributers.length;i++)
        {
            if (contributers[i].hasVoted)
            {
                totalVotedUsers+=1;
                if (contributers[i].approveRequest)
                {
                    yesVotes+=1;
                }
            }
        }

        //51% majority is required with every contributer voted.
        require(manager==msg.sender, "You must be a manager");
        require(totalVotedUsers==contributers.length, "Not every user voted");
        require(yesVotes>contributers.length-yesVotes, "51% majority required");

        user.transfer(_event.currentContrib);
        _event = Event(0,0,0,0);
        contributers = emptyArray;
        requestDescription = "";
    }
}