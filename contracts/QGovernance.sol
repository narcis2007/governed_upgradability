pragma solidity ^0.4.25;

import "./QToken.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";

/**
 * A governance smart contract used for electing the socially-imposed constraints of the decentralized system  
 */
contract QGovernance {
    using SafeMath for uint;
    
    struct Proposal {
        string ipfsHash; 
        address initiator;
        uint electionExpirationTimestamp;
        mapping(address => uint) tokensVoted;
        mapping(address => bool) approved;
        uint totalApproved;
        uint totalDeclined;
        bool exists;
    }
    
    mapping (uint => Proposal) public proposals;
    uint public latestProposalAvailableID = 0;
    QToken public governanceToken;
    QToken public secondaryToken;
    
    constructor(address governanceTokenAddress, address secondaryTokenAddress) public {
        governanceToken = QToken(governanceTokenAddress);
        secondaryToken = QToken(secondaryTokenAddress);
    }
    
    
    function addProposal(string ipfsHash) public returns (uint) {
        //only the token holders can add proposals
        require(governanceToken.balanceOf(msg.sender) != 0);
        Proposal memory p;
        p.ipfsHash = ipfsHash;
        p.initiator = msg.sender;
        p.electionExpirationTimestamp = now + 5 * 1 minutes;
        p.exists = true;
        proposals[latestProposalAvailableID] = p;
        return latestProposalAvailableID++;
        
    }
    
    function voteProposal(uint proposalID, uint amount, bool approved) public {
        
        checkVoteValidity(proposalID, approved);
        
        governanceToken.transferFrom(msg.sender, address(this), amount);
        
        secondaryToken.mint(msg.sender, amount);
        
        processVote(proposalID, amount, approved);
    }
    //TODO: not let people withdraw if there's less time left than a few minutes/hours/days before expiration to prevent misleading votes
    function withdrawTokens(uint proposalID) public {
        uint amount = processWithdrawal(proposalID);
        governanceToken.transfer(msg.sender, amount);
        secondaryToken.burnFrom(msg.sender, amount);
    }
    
    function moveVotesFromProposal(uint sourceProposalID, uint destinationProposalID, bool approved) public {
        uint amount = processWithdrawal(sourceProposalID);
        
        checkVoteValidity(destinationProposalID, approved);
        processVote(destinationProposalID, amount, approved);
        
    }
    
    function checkVoteValidity(uint proposalID, bool approved) internal view {
        Proposal storage p = proposals[proposalID];
        require(p.exists, "proposal doesn't exist");
        require(p.electionExpirationTimestamp > now, "voting disabled after the expiration date");
        require(p.approved[msg.sender]==approved || p.tokensVoted[msg.sender]==0);
    }
    
    function processVote(uint proposalID, uint amount, bool approved) internal {
        Proposal storage p = proposals[proposalID];
        p.tokensVoted[msg.sender] += amount;
        p.approved[msg.sender] = approved;
        
        if(approved){
            p.totalApproved += amount;
        }
        else{
            p.totalDeclined += amount;
        }
        
    }
    
    function processWithdrawal(uint proposalID) internal returns(uint)  {
        Proposal storage p = proposals[proposalID];
        uint amount = p.tokensVoted[msg.sender];
        p.tokensVoted[msg.sender] = 0;
        if(p.electionExpirationTimestamp > now){
            if(p.approved[msg.sender] == true){
                p.totalApproved -= amount;  
            } else {
                p.totalDeclined -= amount; 
            }
        }
        return amount;
    }
    
    function getTokensForProposal(uint proposalID, address who) public view returns(uint)
    {
        return proposals[proposalID].tokensVoted[who];
    }
    
    function getVerdictForProposal(uint proposalID, address who) public view returns(bool)
    {
        return proposals[proposalID].approved[who];
    }
    
    
}
