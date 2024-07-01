// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IERC20.sol";

// A chalenge to create a ballot contract
contract myBallot{

    // Variables
    // This struct creates voters
    struct Voter{
        bool shareholder; // Shows if this person can vote.
        uint256 weight; // Weighting vote of a person
        bool voted; // Voted or not.
        address delegate; // Delegates rights of voting to this address
        bool delegated; // Shows if this person already delegates
        uint256 vote; // Voted option
    }

    // This struct creates new proposals
    struct Proposal{
        uint256 proposalNumber; // Proposal name
        uint256 voteCount; // Counts the total votes of a proposal
    }

    // Dictioary of each voter per address
    mapping(address => Voter) public voter; 
    // This array storages addresses of voters
    address[] internal voterAddresses; 
    // The chairperson address
    address public chairperson; 
    // This array storages the proposals
    Proposal[] public proposals;
    // Defines the minimum token balance to have voting rights
    uint256 public minTokenToVote = 1e4; 
    
    // Token's variables
    IERC20 public token;
    // Total tokens when the contract was created.
    uint256 public maxSupply;

    // ID of this ballot
    uint256 proposalId = 1;

    // Starts contract
    uint256 constructorTime;
    uint256 delay = 86400;
    uint256 duration = 172800;

    // Contract errors
    error InsufficientBalance(uint256 requested, uint256 available);
    error Unauthorized(address senderAddress);
    error OperationFailed(string reason);

    //Contract events
    event SubscriptionResult(address indexed addressVoter, string message);
    event VotingOpened(uint256 _proposalId, uint256 openTime, uint256 closeTime);
    event VotingClosed(uint256 _proposalId, bool passed);
    event GenericEvent(string message);


    // INITIALIZING THE CONTRACT
    constructor(address tokenAddress) {
        chairperson = msg.sender; // creates the chairperson
        token = IERC20(tokenAddress);// links to token
        maxSupply = token.totalSupply(); // Fix the maximum token supply
        constructorTime = block.timestamp; // When the constract was created       
    }

    // MODIFIERS
    modifier OnlyOwner(){
        // Limits access only to chairperson
        require(msg.sender == chairperson, "You need to be a chairperson to use that.");
        _;
    }

    modifier allowedShareholder(){
        // Verifies if the account is a allowed shareholder, if the account can vote.
        require(isShareholder(), "You can't vote, because you don't have enough token balance.");
        require(voter[msg.sender].voted == false, "You've already voted!");
        require(voter[msg.sender].delegated == false, "You've already delegated your right to vote!");
        _;
    }

    modifier allowedDelegater(address _delegate){
        // Virefies if the account can be a delegater
        require(token.balanceOf(_delegate) != 0, "This account doesn't have any token");
        require(voter[_delegate].voted == false, "This account has already voted.");
        _;
    }

    // FUNCTIONS
    function startingContract(uint256 _delay, uint256 _duration) internal view returns(bool){
        uint256 openTime = constructorTime + _delay;
        uint256 closeTime = openTime + _duration;
        if (block.timestamp < openTime || block.timestamp > closeTime){
            return false;
        }else if(block.timestamp >= openTime && block.timestamp <= closeTime){
            return true;
        }else{
            return false;
        }
    }

    function isShareholder() internal returns(bool){
        // This function will be used in the modifier allowedShareholder
        uint256 minWeight = minTokenToVote*1e14/maxSupply;
        if (voter[msg.sender].weight >= minWeight){
            voter[msg.sender].shareholder = true;
            return true;
        }else{
            return false;
        }
    }


    function allowedVoter() public returns (string memory){
        /* 
        This function initiazes the voter in this ballot
        First of all, verifies if the account has token. 
        */
        require(token.balanceOf(msg.sender)>0, "You need to have tokens to subscribe.");

        // Now, it verifies if the account is already subscribed
        for (uint i = 0; i < voterAddresses.length; i++){
            if(voterAddresses[i] == msg.sender){
                revert OperationFailed("You have already been subscribed to our ballot.");
            }
        }
        /*
        Now, if the account does not exist yet, and has token in 
        the account, the contract will check if the account has the
        minimum balance to vote.
        */
        Voter storage v = voter[msg.sender];

        if(token.balanceOf(msg.sender) >= minTokenToVote){
            v.shareholder = true;
            v.weight = voteWeight(msg.sender);
            v.voted = false;
            v.delegate = address(0);
            v.delegated = false;
            v.vote = 0;
            voterAddresses.push(msg.sender);
            emit SubscriptionResult(msg.sender, "Congrats! You were subscribed and you have minimum tokens to vote.");
        }else{
            v.shareholder = false;
            v.weight = voteWeight(msg.sender);
            v.voted = false;
            v.delegate = address(0);
            v.delegated = false;
            v.vote = 0;
            voterAddresses.push(msg.sender);
            emit SubscriptionResult(msg.sender, "Congrats! You were subscribed without voting rights, but you can be a delegated voter.");
        }
        return "Welcome to our ballot.";
    }

    function addProposal(uint256 _proposalNumber) public OnlyOwner returns(Proposal memory){
        // This function adds proposals to be voted.
        proposals.push(Proposal({
            proposalNumber: _proposalNumber,
            voteCount: 0
        }));
        return proposals[proposals.length - 1];
    }

    function voteWeight(address _voteAddress) internal returns (uint256){
        // Defines the weight of a account vote.
        // This function will be used in the function allowedVoter
        voter[_voteAddress].weight = (token.balanceOf(_voteAddress)*1e14)/maxSupply;
        return voter[_voteAddress].weight;
    }

    function transferWeight(address _transferAddress) internal allowedDelegater(_transferAddress) returns (uint256){
        // This is a internal function to transfer weight vote to another account
        voter[_transferAddress].weight += voter[msg.sender].weight;
        voter[msg.sender].weight = 0;
        return voter[_transferAddress].weight;
    }

    function delegationVote(address _delegate) public allowedShareholder returns (string memory){  
        // This function creates the right of a delegated vote
        require(voter[msg.sender].delegate != msg.sender, "You can't delegate for yourself.");
        voter[msg.sender].delegated = true; // Informs that voter delegated his rights
        voter[msg.sender].delegate = _delegate; // Defines the delegated account.
        voter[msg.sender].shareholder = false;
        voter[_delegate].shareholder = true;
        transferWeight(_delegate);
        return "You've transfered your rights to vote";
    }

    function isInArrayProposal(uint256 _proposalNumber) internal returns(bool result){
        // This function will be applied in the function timeToVote
        for (uint256 i = 0; i < proposals.length; i++){
            if (proposals[i].proposalNumber == _proposalNumber){
                proposals[i].voteCount += voter[msg.sender].weight;
                return result = true;
            }
            return result = false;
        }
    }

    function timeToVote(uint256 _proposalNumber) public allowedShareholder returns(string memory){
        // Verifies if the ballot is opened
        require(startingContract(delay, duration), "Your voting attempt is outside the permitted time frame. Please check if the voting period has either not started or has already ended.");
        // This function will count the votes from this ballot
        require(isInArrayProposal(_proposalNumber), "The option does not exist.");
        voter[msg.sender].voted = true;
        voter[msg.sender].vote = _proposalNumber;
        emit GenericEvent("The vote was counted.");
    }

    // Verification functions
    function arrayVoterAdresses() external view returns(address[] memory){
        return voterAddresses;
    }

    function arrayVotes() external view returns (Proposal[] memory){
        return proposals;
    }
}