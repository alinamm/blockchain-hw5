// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract Voting {
    event Accepted(uint256 id);
    event Rejected(uint256 id);
    event Discarded(uint256 id);
    event Created(uint256 id, uint256 deadline);

    uint constant PROPOSALS_LIMIT = 3;
    uint constant TTL_OF_PROPOSAL = 3 * 24 * 60 * 60; // time-to-live(TTL) of proposal is 3 days

    struct Proposal {
        uint256 id;
        bool isActive;
        address ownerAddress;
        Vote[] votesFor;
        Vote[] votesAgainst;
        uint256 deadline;
    }

    Proposal[PROPOSALS_LIMIT] public proposals;

    ERC20 public token;

    constructor(ERC20 _token) {
        token = _token;
    }

    struct Vote {
        address voter;
        uint256 weight;
        bool votingFor;
    }

    function getNewProposal(uint256 id) public {
        uint index = 0;
        bool found = false;
        for (uint i = 0; i < PROPOSALS_LIMIT; i++) {
            // finding free proposal index
            if (!proposals[i].isActive) {
                index = i;
                found = true;
            }
        }
        if (!found) {
            uint256 deadline = block.timestamp;
            for (uint i = 0; i < PROPOSALS_LIMIT; i++) {
                // checking if deadline approached
                if (proposals[i].deadline < deadline) {
                    index = i;
                    found = true;
                }
            }
        }
        if (!found) {
            index = PROPOSALS_LIMIT;
        }
        require(index < PROPOSALS_LIMIT, "Reached maximum of active proposals");

        bool found2 = false;
        for (uint i = 0; i < PROPOSALS_LIMIT; i++) {
            if (proposals[i].id == id) {
                found2 = true;
            }
        }
        require(found2 == false, "Proposal with this id exists");
        Proposal storage proposal = proposals[index];
        if (proposal.isActive) {
            // Make proposal discarded
            emit Discarded(proposal.id);
        }
        // setting new proposal
        proposal.id = id;
        proposal.isActive = true;
        proposal.ownerAddress = msg.sender;
        delete proposal.votesFor;
        delete proposal.votesAgainst;
        proposal.deadline = block.timestamp + TTL_OF_PROPOSAL;
        emit Created(proposal.id, proposal.deadline);
    }

    function vote(uint256 id, bool isVoteFor, uint256 value) public {
        require(value > 0, "Value should be positive");
        require(token.balanceOf(msg.sender) >= value, "This voter doesn't have enough tokens");

        uint index = 0;
        bool found = false;
        for (uint i = 0; i < PROPOSALS_LIMIT; i++) {
            if (proposals[i].id == id) {
                index = i;
                found = true;
            }
        }
        if (!found) {
            index = PROPOSALS_LIMIT;
        }
        require(index != PROPOSALS_LIMIT, "No such proposal");
        Proposal storage proposal = proposals[index];
        require(!(proposal.deadline < block.timestamp), "Proposal has expired");
        require(!_voted(msg.sender, proposal), "Already voted for proposal");

        // state of votes is invalid --- emit Discarded
        if (!_proposalValid(proposal)) {
            proposal.isActive = false;
            emit Discarded(id);
            return;
        }
        // create vote
        Vote memory vote = Vote(msg.sender, value, isVoteFor);
        if (isVoteFor) {
            // vote for
            proposal.votesFor.push(vote);
        } else {
            // vote against
            proposal.votesAgainst.push(vote);
        }
        if (_getVotesNumber(proposal.votesFor) > 50) {
            // votes for > 50 => accepted
            emit Accepted(proposal.id);
            proposal.isActive = false;
        } else if (_getVotesNumber(proposal.votesAgainst) > 50) {
            // votes against > 50 => rejected
            emit Rejected(proposal.id);
            proposal.isActive = false;
        } else {
            proposal.isActive = true;
        }
    }

    function ifProposalIsActive(uint256 id) public view returns (bool) {
        uint index = 0;
        bool found = false;
        for (uint i = 0; i < PROPOSALS_LIMIT; i++) {
            if (proposals[i].id == id) {
                index = i;
                found = true;
            }
        }
        if (!found) {
            index = PROPOSALS_LIMIT;
        }
        // checking if proposal is active
        if (index == PROPOSALS_LIMIT) {
            return false;
        }
        return proposals[index].isActive;
    }

    function _proposalValid(Proposal storage proposal) internal view returns (bool) {
        uint len = proposal.votesAgainst.length >= proposal.votesFor.length ? proposal.votesAgainst.length : proposal.votesFor.length;
        for (uint i = 0; i < len; i++) {
            // check if proposal is valid
            if (i < proposal.votesFor.length
            && token.balanceOf(proposal.votesFor[i].voter) < proposal.votesFor[i].weight
                || i < proposal.votesAgainst.length
                && token.balanceOf(proposal.votesAgainst[i].voter) < proposal.votesAgainst[i].weight) {
                return false;
            }
        }
        return true;
    }

    function _voted(address voter, Proposal storage proposal) internal view returns (bool) {
        uint len = proposal.votesAgainst.length >= proposal.votesFor.length ? proposal.votesAgainst.length : proposal.votesFor.length;
        for (uint i = 0; i < len; i++) {
            if ((i < proposal.votesFor.length && proposal.votesFor[i < proposal.votesFor.length ? i : 0].voter == voter)
                || (i < proposal.votesAgainst.length && proposal.votesAgainst[i < proposal.votesAgainst.length ? i : 0].voter == voter)) {
                return true;
            }
        }
        return false;
    }

    function _getVotesNumber(Vote[] storage votes) internal view returns (uint256) {
        uint256 result = 0;
        for (uint i = 0; i < votes.length; i++) {
            // counting number of votes
            result += votes[i].weight;
        }
        return result;
    }
}
