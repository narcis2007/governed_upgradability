pragma solidity ^0.4.25;

import "./QToken.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";

/**
 * A governance smart contract used for electing the current active configuration of the decentralized system  
 */
contract QContinousGovernance {
    using SafeMath for uint;
    
    struct ConfigurationProposal {
        string ipfsHash; //At this link a document containing the description of the proposed configuration can be found
        address configurationContract;
        address initiator;
        mapping(address => uint) tokensVoted;
        mapping(address => bool) approved;
        uint totalApproved;
        uint totalDeclined;
        bool exists;
        uint id;
    }
    
    mapping (uint => ConfigurationProposal) public proposals;
    uint public latestProposalAvailableID = 0;
    QToken public governanceToken;
    QToken public secondaryToken;
    
    ConfigurationProposal public activeConfiguraration;
    
    constructor(address governanceTokenAddress, address secondaryTokenAddress) public {
        governanceToken = QToken(governanceTokenAddress);
        secondaryToken = QToken(secondaryTokenAddress);
    }
    
    
    function addProposal(string ipfsHash, address configurationContract) public returns (uint) {
        //only the token holders can add proposals
        require(governanceToken.balanceOf(msg.sender) != 0);
        ConfigurationProposal memory p;
        p.ipfsHash = ipfsHash;
        p.initiator = msg.sender;
        p.configurationContract = configurationContract;
        p.exists = true;
        p.id = latestProposalAvailableID;
        proposals[latestProposalAvailableID] = p;
        return latestProposalAvailableID++;
        
    }
    
    function voteProposal(uint proposalID, uint amount, bool approved) public {
        
        checkVoteValidity(proposalID, approved);
        
        governanceToken.transferFrom(msg.sender, address(this), amount);
        
        //secondaryToken.mint(msg.sender, amount);
        
        processVote(proposalID, amount, approved);
    }
    
    function withdrawTokens(uint proposalID) public {
        uint amount = processWithdrawal(proposalID);
        governanceToken.transfer(msg.sender, amount);
        //secondaryToken.burnFrom(msg.sender, amount);
    }
    
    function moveVotesFromProposal(uint sourceProposalID, uint destinationProposalID, bool approved) public {
        uint amount = processWithdrawal(sourceProposalID);
        
        checkVoteValidity(destinationProposalID, approved);
        processVote(destinationProposalID, amount, approved);
        
    }
    
    function actualizeActiveConfiguration(uint proposalID) public {
        ConfigurationProposal storage p = proposals[proposalID];
        if(p.totalApproved > activeConfiguraration.totalApproved)
            activeConfiguraration = p;
    }
    
    function checkVoteValidity(uint proposalID, bool approved) internal view {
        ConfigurationProposal storage p = proposals[proposalID];
        require(p.exists, "proposal doesn't exist");
        require(p.approved[msg.sender]==approved || p.tokensVoted[msg.sender]==0);
    }
    
    function processVote(uint proposalID, uint amount, bool approved) internal {
        ConfigurationProposal storage p = proposals[proposalID];
        p.tokensVoted[msg.sender] += amount;
        p.approved[msg.sender] = approved;
        
        if(approved){
            p.totalApproved += amount;
        }
        else{
            p.totalDeclined += amount;
        }
        if(p.totalApproved > activeConfiguraration.totalApproved)
            activeConfiguraration = p;
        
    }
    
    function processWithdrawal(uint proposalID) internal returns(uint)  {
        ConfigurationProposal storage p = proposals[proposalID];
        uint amount = p.tokensVoted[msg.sender];
        p.tokensVoted[msg.sender] = 0;
        if(p.approved[msg.sender] == true){
            p.totalApproved -= amount;  
        } else {
            p.totalDeclined -= amount; 
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
    
    function getActiveConfigurationID() public view returns(uint){
        return activeConfiguraration.id;
    }
    
    
}
