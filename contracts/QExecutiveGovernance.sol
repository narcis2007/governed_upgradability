pragma solidity ^0.4.25;

import "./QToken.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";

/**
 * An executive governance smart contract used for sending any kind of transactions on behalf of the decentralized system with their approval
 */
contract QExecutiveGovernance {
    using SafeMath for uint;

    struct TransactionProposal {
        address destination;
        uint value;
        bytes data;
        bool executed;
        address initiator;
        uint electionExpirationTimestamp;
        mapping(address => uint) tokensVoted;
        mapping(address => bool) approved;
        uint totalApproved;
        uint totalDeclined;
        bool exists;
    }

    mapping(uint => TransactionProposal) public transactionProposals;
    uint public latestTransactionProposalAvailableID = 0;
    QToken public governanceToken;
    QToken public secondaryToken;
    
    event Execution(uint proposalID);
    event ExecutionFailure(uint proposalID);

    constructor(address governanceTokenAddress, address secondaryTokenAddress) public {
        governanceToken = QToken(governanceTokenAddress);
        secondaryToken = QToken(secondaryTokenAddress);
    }

    function addProposal(address destination, uint value, bytes data) public returns (uint) {
        //only the token holders can add proposals
        require(governanceToken.balanceOf(msg.sender) != 0);
        TransactionProposal memory p;
        p.destination = destination;
        p.value = value;
        p.data = data;
        p.initiator = msg.sender;
        p.electionExpirationTimestamp = now + 5 * 1 minutes;
        p.exists = true;
        transactionProposals[latestTransactionProposalAvailableID] = p;
        return latestTransactionProposalAvailableID++;

    }
    
    function voteProposal(uint proposalID, uint amount, bool approved) public {

        checkVoteValidity(proposalID, approved);

        governanceToken.transferFrom(msg.sender, address(this), amount);

//        secondaryToken.mint(msg.sender, amount);

        processVote(proposalID, amount, approved);
    }

    //TODO: not let people withdraw if there's less time left than a few minutes/hours/days before expiration to prevent misleading votes
    function withdrawTokens(uint proposalID) public {
        uint amount = processWithdrawal(proposalID);
        governanceToken.transfer(msg.sender, amount);
//        secondaryToken.burnFrom(msg.sender, amount);
    }

    function moveVotesFromProposal(uint sourceProposalID, uint destinationProposalID, bool approved) public {
        uint amount = processWithdrawal(sourceProposalID);

        checkVoteValidity(destinationProposalID, approved);
        processVote(destinationProposalID, amount, approved);

    }

    function executeTransaction(uint proposalID) public {
        if (transactionProposals[proposalID].executed)
            revert();
        if (isTransactionProposalConfirmed(proposalID)) {
            TransactionProposal storage tp = transactionProposals[proposalID];
            tp.executed = true;
            if (tp.destination.call.value(tp.value)(tp.data))
                emit Execution(proposalID);
            else {
                emit ExecutionFailure(proposalID);
                tp.executed = false;
            }
        }
    }

    function checkVoteValidity(uint proposalID, bool approved) internal view {
        TransactionProposal storage p = transactionProposals[proposalID];
        require(p.exists, "proposal doesn't exist");
        require(p.electionExpirationTimestamp > now, "voting disabled after the expiration date");
        require(p.approved[msg.sender] == approved || p.tokensVoted[msg.sender] == 0);
    }

    function processVote(uint proposalID, uint amount, bool approved) internal {
        TransactionProposal storage p = transactionProposals[proposalID];
        p.tokensVoted[msg.sender] += amount;
        p.approved[msg.sender] = approved;

        if (approved) {
            p.totalApproved += amount;
        }
        else {
            p.totalDeclined += amount;
        }

    }

    function processWithdrawal(uint proposalID) internal returns (uint)  {
        TransactionProposal storage p = transactionProposals[proposalID];
        uint amount = p.tokensVoted[msg.sender];
        p.tokensVoted[msg.sender] = 0;
        if (p.electionExpirationTimestamp > now) {
            if (p.approved[msg.sender] == true) {
                p.totalApproved -= amount;
            } else {
                p.totalDeclined -= amount;
            }
        }
        return amount;
    }
    
    function isTransactionProposalConfirmed(uint transactionProposalID) public view returns (bool){
        TransactionProposal storage tp = transactionProposals[transactionProposalID];
        return tp.electionExpirationTimestamp < now && tp.totalApproved > tp.totalDeclined;
    }


    function getTokensForProposal(uint proposalID, address who) public view returns (uint)
    {
        return transactionProposals[proposalID].tokensVoted[who];
    }

    function getVerdictForProposal(uint proposalID, address who) public view returns (bool)
    {
        return transactionProposals[proposalID].approved[who];
    }


}
