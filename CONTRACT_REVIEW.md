# Contract Review Input - Voting DApp

## Huong dan
1. Dan toan bo code Solidity vao muc "Contract Code" ben duoi.
2. Neu co nhieu file, dan het theo tung khoi ro rang.
3. Neu co thong tin bo sung (network, compiler version, constructor args), dien vao muc Metadata.

## Metadata
- Solidity version:
- Compiler settings (optimizer runs):
- Target network (Ganache/Sepolia):
- Contract chinh (ten file + ten contract):
- Cac contract/phien ban lien quan:

## Contract Code
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Candidate {
        uint id;
        string name;
        address candidateAddress;
        uint voteCount;
    }

    address public owner;
    uint public endTime;
    uint public candidatesCount;
    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;

    modifier onlyOwner() {
        require(msg.sender == owner, "Chi Admin moi co quyen nay!");
        _;
    }

    modifier onlyDuringVoting() {
        require(block.timestamp < endTime, "Cuoc bau cu da ket thuc!");
        _;
    }

    // Constructor nhan admin tu Factory
    constructor(uint _durationInMinutes, address _admin) {
        owner = _admin;
        endTime = block.timestamp + (_durationInMinutes * 1 minutes);
    }

    function addCandidate(string memory _name, address _address) public onlyOwner {
        require(block.timestamp < endTime, "Het gio them ung vien!");
        candidatesCount ++;
        candidates[candidatesCount] = Candidate(candidatesCount, _name, _address, 0);
    }

    function vote(uint _candidateId) public onlyDuringVoting {
        require(msg.sender != owner, "Admin khong duoc bau chon!");
        require(!voters[msg.sender], "Ban da bau roi!");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "ID sai!");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount ++;
    }

    function getAllCandidates() public view returns (Candidate[] memory) {
        Candidate[] memory items = new Candidate[](candidatesCount);
        for (uint i = 1; i <= candidatesCount; i++) {
            items[i-1] = candidates[i];
        }
        return items;
    }

    function getWinner() public view returns (string memory name, uint votes) {
        uint winningVoteCount = 0;
        uint winningId = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winningId = i;
            }
        }
        if (winningVoteCount == 0) return ("Chua co ai", 0);
        return (candidates[winningId].name, candidates[winningId].voteCount);
    }
}

contract VotingFactory {
    address[] public deployedVotings;

    function createVoting(uint _minutes) public {
        Voting newVoting = new Voting(_minutes, msg.sender);
        deployedVotings.push(address(newVoting));
    }

    function getDeployedVotings() public view returns (address[] memory) {
        return deployedVotings;
    }
}

## ABI (neu co)
[
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "_name",
        "type": "string"
      },
      {
        "internalType": "address",
        "name": "_address",
        "type": "address"
      }
    ],
    "name": "addCandidate",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_durationInMinutes",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "_admin",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_candidateId",
        "type": "uint256"
      }
    ],
    "name": "vote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "name": "candidates",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      },
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "address",
        "name": "candidateAddress",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "voteCount",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "candidatesCount",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "endTime",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getAllCandidates",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "string",
            "name": "name",
            "type": "string"
          },
          {
            "internalType": "address",
            "name": "candidateAddress",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "voteCount",
            "type": "uint256"
          }
        ],
        "internalType": "struct Voting.Candidate[]",
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getWinner",
    "outputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "uint256",
        "name": "votes",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "voters",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]

## Cac cau hoi ban muon duoc review uu tien
- Vi du: whitelist co chac chan an toan khong?
- Vi du: flow startElection/endElection da dung nghiep vu chua?
- Vi du: co loi nao de bi vote 2 lan khong?
