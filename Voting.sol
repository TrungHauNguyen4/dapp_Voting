// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Voting DApp - one contract, many election rounds
/// @notice This contract keeps a single permanent address while allowing admin to open new rounds.
contract Voting {
    enum State {
        Created,
        Voting,
        Ended
    }

    struct Candidate {
        uint256 id;
        string name;
        string image;
        uint256 voteCount;
    }

    struct ElectionRound {
        State state;
        uint256 startTime;
        uint256 endTime;
        uint256 candidatesCount;
        bool exists;
    }

    address public admin;
    uint256 public currentElectionId;

    mapping(uint256 => ElectionRound) private elections;
    mapping(uint256 => mapping(uint256 => Candidate)) private electionCandidates;
    mapping(uint256 => mapping(address => bool)) private electionWhitelist;
    mapping(uint256 => mapping(address => bool)) private electionVoted;

    event ElectionCreated(uint256 indexed electionId, uint256 createdAt);
    event VoterRegistered(address indexed voter);
    event CandidateAdded(uint256 indexed candidateId, string name, string image);
    event ElectionStarted(uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, uint256 indexed candidateId);
    event ElectionEnded(uint256 endTime);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Chi Admin moi co quyen");
        _;
    }

    modifier inState(State expected) {
        require(_effectiveState(currentElectionId) == expected, "Trang thai bau cu khong hop le");
        _;
    }

    constructor() {
        admin = msg.sender;
        _createNewElection();
    }

    /// @notice Open a new election round after previous round has ended.
    function createElection() external onlyAdmin {
        _finalizeIfNeeded(currentElectionId);
        require(elections[currentElectionId].state == State.Ended, "Ky bau hien tai chua ket thuc");
        _createNewElection();
    }

    /// @notice Chot ket qua neu da het gio; bat ky ai cung co the goi.
    function finalizeElectionIfEnded() external {
        _finalizeIfNeeded(currentElectionId);
        require(elections[currentElectionId].state == State.Ended, "Ky bau cu chua den luc ket thuc");
    }

    function _effectiveState(uint256 electionId) private view returns (State) {
        ElectionRound storage round = elections[electionId];

        if (round.state == State.Voting && round.endTime > 0 && block.timestamp > round.endTime) {
            return State.Ended;
        }

        return round.state;
    }

    function _finalizeIfNeeded(uint256 electionId) private {
        ElectionRound storage round = elections[electionId];

        if (round.state == State.Voting && round.endTime > 0 && block.timestamp > round.endTime) {
            round.state = State.Ended;
            emit ElectionEnded(round.endTime);
        }
    }

    function _createNewElection() private {
        currentElectionId += 1;
        elections[currentElectionId] = ElectionRound({
            state: State.Created,
            startTime: 0,
            endTime: 0,
            candidatesCount: 0,
            exists: true
        });
        emit ElectionCreated(currentElectionId, block.timestamp);
    }

    function registerVoter(address _voter) external onlyAdmin inState(State.Created) {
        require(_voter != address(0), "Dia chi vi khong hop le");
        require(!electionWhitelist[currentElectionId][_voter], "Vi da duoc dang ky");

        electionWhitelist[currentElectionId][_voter] = true;
        emit VoterRegistered(_voter);
    }

    function registerVoters(address[] calldata _voters) external onlyAdmin inState(State.Created) {
        uint256 length = _voters.length;
        require(length > 0, "Danh sach rong");

        for (uint256 i = 0; i < length; i++) {
            address voterAddr = _voters[i];
            if (voterAddr != address(0) && !electionWhitelist[currentElectionId][voterAddr]) {
                electionWhitelist[currentElectionId][voterAddr] = true;
                emit VoterRegistered(voterAddr);
            }
        }
    }

    function addCandidate(string calldata _name, string calldata _image) external onlyAdmin inState(State.Created) {
        require(bytes(_name).length > 0, "Ten ung cu vien khong duoc rong");

        ElectionRound storage round = elections[currentElectionId];
        round.candidatesCount += 1;

        electionCandidates[currentElectionId][round.candidatesCount] = Candidate({
            id: round.candidatesCount,
            name: _name,
            image: _image,
            voteCount: 0
        });

        emit CandidateAdded(round.candidatesCount, _name, _image);
    }

    function addCandidate(string calldata _name) external onlyAdmin inState(State.Created) {
        require(bytes(_name).length > 0, "Ten ung cu vien khong duoc rong");

        ElectionRound storage round = elections[currentElectionId];
        round.candidatesCount += 1;

        electionCandidates[currentElectionId][round.candidatesCount] = Candidate({
            id: round.candidatesCount,
            name: _name,
            image: "",
            voteCount: 0
        });

        emit CandidateAdded(round.candidatesCount, _name, "");
    }

    function startElection(uint256 durationSeconds) external onlyAdmin inState(State.Created) {
        ElectionRound storage round = elections[currentElectionId];
        require(round.candidatesCount > 0, "Chua co ung cu vien");
        require(durationSeconds > 0, "Thoi gian bau cu phai > 0");

        round.state = State.Voting;
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + durationSeconds;

        emit ElectionStarted(round.startTime, round.endTime);
    }

    function endElection() external onlyAdmin inState(State.Voting) {
        ElectionRound storage round = elections[currentElectionId];
        require(block.timestamp >= round.endTime, "Chua den thoi diem ket thuc");

        round.state = State.Ended;
        emit ElectionEnded(block.timestamp);
    }

    function vote(uint256 _candidateId) external inState(State.Voting) {
        ElectionRound storage round = elections[currentElectionId];
        require(electionWhitelist[currentElectionId][msg.sender], "Vi khong nam trong whitelist");
        require(!electionVoted[currentElectionId][msg.sender], "Ban da bo phieu");
        require(block.timestamp <= round.endTime, "Cuoc bau cu da het gio");
        require(_candidateId > 0 && _candidateId <= round.candidatesCount, "ID ung cu vien khong hop le");

        electionVoted[currentElectionId][msg.sender] = true;
        electionCandidates[currentElectionId][_candidateId].voteCount += 1;

        emit VoteCast(msg.sender, _candidateId);
    }

    // ===== Compatibility getters (current round) =====

    function electionState() external view returns (State) {
        return _effectiveState(currentElectionId);
    }

    function endTime() external view returns (uint256) {
        return elections[currentElectionId].endTime;
    }

    function candidatesCount() external view returns (uint256) {
        return elections[currentElectionId].candidatesCount;
    }

    function candidates(uint256 candidateId) external view returns (uint256 id, string memory name, string memory image, uint256 voteCount) {
        Candidate storage c = electionCandidates[currentElectionId][candidateId];
        return (c.id, c.name, c.image, c.voteCount);
    }

    function isRegistered(address wallet) external view returns (bool) {
        return electionWhitelist[currentElectionId][wallet];
    }

    function voters(address wallet) external view returns (bool) {
        return electionVoted[currentElectionId][wallet];
    }

    function getResults() external view inState(State.Ended) returns (Candidate[] memory) {
        ElectionRound storage round = elections[currentElectionId];
        Candidate[] memory results = new Candidate[](round.candidatesCount);

        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            results[i - 1] = electionCandidates[currentElectionId][i];
        }

        return results;
    }

    function getAllCandidates() external view returns (Candidate[] memory) {
        ElectionRound storage round = elections[currentElectionId];
        Candidate[] memory items = new Candidate[](round.candidatesCount);

        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            items[i - 1] = electionCandidates[currentElectionId][i];
        }

        return items;
    }

    function getWinner() external view returns (string memory name, uint256 votes) {
        ElectionRound storage round = elections[currentElectionId];
        uint256 winningVoteCount = 0;
        uint256 winningId = 0;

        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            if (electionCandidates[currentElectionId][i].voteCount > winningVoteCount) {
                winningVoteCount = electionCandidates[currentElectionId][i].voteCount;
                winningId = i;
            }
        }

        if (winningVoteCount == 0) {
            return ("Chua co ai", 0);
        }

        return (
            electionCandidates[currentElectionId][winningId].name,
            electionCandidates[currentElectionId][winningId].voteCount
        );
    }

    // ===== Optional history helpers =====

    function getElectionMeta(uint256 electionId)
        external
        view
        returns (State state, uint256 startTime, uint256 endAt, uint256 totalCandidates)
    {
        ElectionRound storage round = elections[electionId];
        require(round.exists, "Ky bau cu khong ton tai");
        return (_effectiveState(electionId), round.startTime, round.endTime, round.candidatesCount);
    }

    function getAllCandidatesByElection(uint256 electionId) external view returns (Candidate[] memory) {
        ElectionRound storage round = elections[electionId];
        require(round.exists, "Ky bau cu khong ton tai");

        Candidate[] memory items = new Candidate[](round.candidatesCount);
        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            items[i - 1] = electionCandidates[electionId][i];
        }

        return items;
    }

    function isRegisteredInElection(uint256 electionId, address wallet) external view returns (bool) {
        require(elections[electionId].exists, "Ky bau cu khong ton tai");
        return electionWhitelist[electionId][wallet];
    }

    function hasVotedInElection(uint256 electionId, address wallet) external view returns (bool) {
        require(elections[electionId].exists, "Ky bau cu khong ton tai");
        return electionVoted[electionId][wallet];
    }
}
