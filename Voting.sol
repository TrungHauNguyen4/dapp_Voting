// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Voting DApp - one contract, many election rounds
/// @notice This contract keeps a single permanent address while allowing admin to open new rounds.
contract Voting {
    // Trang thai cua 1 ky bau cu.
    enum State {
        // Moi tao ky, chua mo bo phieu.
        Created,
        // Dang trong thoi gian bo phieu.
        Voting,
        // Da dong bo phieu.
        Ended
    }

    // Du lieu cua 1 ung cu vien trong 1 ky bau cu cu the.
    struct Candidate {
        // ID chay tu 1..N trong ky hien tai.
        uint256 id;
        // Ten hien thi cua ung cu vien.
        string name;
        // Anh dai dien (URL/base64), co the rong.
        string image;
        // Tong so phieu nhan duoc trong ky.
        uint256 voteCount;
    }

    // Metadata cua moi ky bau cu.
    struct ElectionRound {
        // Trang thai ky bau cu.
        State state;
        // Moc bat dau (unix timestamp, giay).
        uint256 startTime;
        // Moc ket thuc (unix timestamp, giay).
        uint256 endTime;
        // So ung cu vien da duoc them.
        uint256 candidatesCount;
        // Danh dau ky nay da ton tai hay chua.
        bool exists;
    }

    // Dia chi admin duy nhat cua contract.
    address public admin;
    // ID ky bau cu hien tai (tang dan theo thoi gian).
    uint256 public currentElectionId;

    // electionId -> thong tin tong quan ky bau cu.
    mapping(uint256 => ElectionRound) private elections;
    // electionId -> candidateId -> thong tin ung cu vien.
    mapping(uint256 => mapping(uint256 => Candidate)) private electionCandidates;
    // electionId -> voterAddress -> co nam trong whitelist hay khong.
    mapping(uint256 => mapping(address => bool)) private electionWhitelist;
    // electionId -> voterAddress -> da bo phieu hay chua.
    mapping(uint256 => mapping(address => bool)) private electionVoted;

    // Event phuc vu truy vet on-chain/off-chain sync.
    event ElectionCreated(uint256 indexed electionId, uint256 createdAt);
    event VoterRegistered(address indexed voter);
    event CandidateAdded(uint256 indexed candidateId, string name, string image);
    event ElectionStarted(uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, uint256 indexed candidateId);
    event ElectionEnded(uint256 endTime);

    // Chi cho phep admin goi ham.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Chi Admin moi co quyen");
        _;
    }

    // Chi cho phep ham chay trong dung trang thai ky hien tai.
    modifier inState(State expected) {
        require(elections[currentElectionId].state == expected, "Trang thai bau cu khong hop le");
        _;
    }

    // Khi deploy: set admin va tao ngay ky bau cu dau tien (state = Created).
    constructor() {
        admin = msg.sender;
        _createNewElection();
    }

    /// @notice Open a new election round after previous round has ended.
    /// @dev Chi admin goi duoc, va ky hien tai bat buoc da Ended.
    function createElection() external onlyAdmin {
        require(elections[currentElectionId].state == State.Ended, "Ky bau hien tai chua ket thuc");
        _createNewElection();
    }

    // Tao ky moi voi du lieu ban dau rong.
    function _createNewElection() private {
        // Tang ID ky truoc, roi khoi tao ky moi.
        currentElectionId += 1;
        elections[currentElectionId] = ElectionRound({
            state: State.Created,
            startTime: 0,
            endTime: 0,
            candidatesCount: 0,
            exists: true
        });
        // Ghi log tao ky de backend co the dong bo.
        emit ElectionCreated(currentElectionId, block.timestamp);
    }

    // Dang ky 1 cu tri vao whitelist cua ky hien tai.
    function registerVoter(address _voter) external onlyAdmin inState(State.Created) {
        // Chan dia chi 0x0.
        require(_voter != address(0), "Dia chi vi khong hop le");
        // Khong cho dang ky trung.
        require(!electionWhitelist[currentElectionId][_voter], "Vi da duoc dang ky");

        electionWhitelist[currentElectionId][_voter] = true;
        emit VoterRegistered(_voter);
    }

    // Dang ky hang loat cu tri (batch) de tiet kiem thao tac.
    function registerVoters(address[] calldata _voters) external onlyAdmin inState(State.Created) {
        uint256 length = _voters.length;
        require(length > 0, "Danh sach rong");

        for (uint256 i = 0; i < length; i++) {
            address voterAddr = _voters[i];
            // Bo qua dia chi loi hoac da co san, khong revert toan bo lo.
            if (voterAddr != address(0) && !electionWhitelist[currentElectionId][voterAddr]) {
                electionWhitelist[currentElectionId][voterAddr] = true;
                emit VoterRegistered(voterAddr);
            }
        }
    }

    // Overload 1: them ung cu vien co kem anh.
    function addCandidate(string calldata _name, string calldata _image) external onlyAdmin inState(State.Created) {
        require(bytes(_name).length > 0, "Ten ung cu vien khong duoc rong");

        // Dung storage de cap nhat truc tiep du lieu trong state.
        ElectionRound storage round = elections[currentElectionId];
        // Tang bo dem va dung chinh so moi lam candidateId.
        round.candidatesCount += 1;

        electionCandidates[currentElectionId][round.candidatesCount] = Candidate({
            id: round.candidatesCount,
            name: _name,
            image: _image,
            voteCount: 0
        });

        emit CandidateAdded(round.candidatesCount, _name, _image);
    }

    // Overload 2: them ung cu vien khong anh.
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

    // Mo bo phieu voi thoi luong tinh theo giay.
    function startElection(uint256 durationSeconds) external onlyAdmin inState(State.Created) {
        ElectionRound storage round = elections[currentElectionId];
        // Phai co it nhat 1 ung cu vien moi duoc start.
        require(round.candidatesCount > 0, "Chua co ung cu vien");
        require(durationSeconds > 0, "Thoi gian bau cu phai > 0");

        round.state = State.Voting;
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + durationSeconds;

        emit ElectionStarted(round.startTime, round.endTime);
    }

    // Dong bo phieu. Admin chi ket thuc duoc khi da qua endTime.
    function endElection() external onlyAdmin inState(State.Voting) {
        ElectionRound storage round = elections[currentElectionId];
        require(block.timestamp >= round.endTime, "Chua den thoi diem ket thuc");

        round.state = State.Ended;
        emit ElectionEnded(block.timestamp);
    }

    // Cu tri bo phieu cho 1 ung cu vien.
    function vote(uint256 _candidateId) external inState(State.Voting) {
        ElectionRound storage round = elections[currentElectionId];
        // Chi whitelist moi vote duoc.
        require(electionWhitelist[currentElectionId][msg.sender], "Vi khong nam trong whitelist");
        // Moi vi chi duoc 1 phieu/ky.
        require(!electionVoted[currentElectionId][msg.sender], "Ban da bo phieu");
        // Het gio thi khong duoc vote nua.
        require(block.timestamp <= round.endTime, "Cuoc bau cu da het gio");
        // Candidate id phai nam trong range hop le.
        require(_candidateId > 0 && _candidateId <= round.candidatesCount, "ID ung cu vien khong hop le");

        // Danh dau da vote truoc, roi moi cong phieu (chong vote lai trong cung tx flow).
        electionVoted[currentElectionId][msg.sender] = true;
        electionCandidates[currentElectionId][_candidateId].voteCount += 1;

        emit VoteCast(msg.sender, _candidateId);
    }

    // ===== Compatibility getters (current round) =====
    // Nhom ham ben duoi giu giao dien doc du lieu don gian cho frontend cu.

    // Lay trang thai ky hien tai.
    function electionState() external view returns (State) {
        return elections[currentElectionId].state;
    }

    // Lay endTime ky hien tai.
    function endTime() external view returns (uint256) {
        return elections[currentElectionId].endTime;
    }

    // So ung cu vien trong ky hien tai.
    function candidatesCount() external view returns (uint256) {
        return elections[currentElectionId].candidatesCount;
    }

    // Lay thong tin 1 ung cu vien theo candidateId trong ky hien tai.
    function candidates(uint256 candidateId) external view returns (uint256 id, string memory name, string memory image, uint256 voteCount) {
        Candidate storage c = electionCandidates[currentElectionId][candidateId];
        return (c.id, c.name, c.image, c.voteCount);
    }

    // Kiem tra vi co nam trong whitelist cua ky hien tai khong.
    function isRegistered(address wallet) external view returns (bool) {
        return electionWhitelist[currentElectionId][wallet];
    }

    // Kiem tra vi da vote trong ky hien tai chua.
    function voters(address wallet) external view returns (bool) {
        return electionVoted[currentElectionId][wallet];
    }

    // Tra ve danh sach ket qua khi ky da ket thuc.
    function getResults() external view inState(State.Ended) returns (Candidate[] memory) {
        ElectionRound storage round = elections[currentElectionId];
        Candidate[] memory results = new Candidate[](round.candidatesCount);

        // Mapping khong the tra ve all key, nen can lap tu 1..candidatesCount.
        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            results[i - 1] = electionCandidates[currentElectionId][i];
        }

        return results;
    }

    // Tra ve toan bo ung cu vien (ke ca khi chua ket thuc).
    function getAllCandidates() external view returns (Candidate[] memory) {
        ElectionRound storage round = elections[currentElectionId];
        Candidate[] memory items = new Candidate[](round.candidatesCount);

        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            items[i - 1] = electionCandidates[currentElectionId][i];
        }

        return items;
    }

    // Tim nguoi dan dau theo so phieu trong ky hien tai.
    function getWinner() external view returns (string memory name, uint256 votes) {
        ElectionRound storage round = elections[currentElectionId];
        // Gia tri max tam thoi.
        uint256 winningVoteCount = 0;
        // ID ung cu vien dang dan dau.
        uint256 winningId = 0;

        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            // Chi cap nhat khi tim thay so phieu lon hon.
            if (electionCandidates[currentElectionId][i].voteCount > winningVoteCount) {
                winningVoteCount = electionCandidates[currentElectionId][i].voteCount;
                winningId = i;
            }
        }

        // Chua co phieu nao hop le.
        if (winningVoteCount == 0) {
            return ("Chua co ai", 0);
        }

        return (
            electionCandidates[currentElectionId][winningId].name,
            electionCandidates[currentElectionId][winningId].voteCount
        );
    }

    // ===== Optional history helpers =====
    // Nhom ham ben duoi dung khi can doc du lieu theo electionId cu the.

    // Lay metadata cua 1 ky bat ky.
    function getElectionMeta(uint256 electionId)
        external
        view
        returns (State state, uint256 startTime, uint256 endAt, uint256 totalCandidates)
    {
        ElectionRound storage round = elections[electionId];
        require(round.exists, "Ky bau cu khong ton tai");
        return (round.state, round.startTime, round.endTime, round.candidatesCount);
    }

    // Lay danh sach ung cu vien theo 1 ky cu the.
    function getAllCandidatesByElection(uint256 electionId) external view returns (Candidate[] memory) {
        ElectionRound storage round = elections[electionId];
        require(round.exists, "Ky bau cu khong ton tai");

        Candidate[] memory items = new Candidate[](round.candidatesCount);
        for (uint256 i = 1; i <= round.candidatesCount; i++) {
            items[i - 1] = electionCandidates[electionId][i];
        }

        return items;
    }

    // Kiem tra whitelist theo electionId.
    function isRegisteredInElection(uint256 electionId, address wallet) external view returns (bool) {
        require(elections[electionId].exists, "Ky bau cu khong ton tai");
        return electionWhitelist[electionId][wallet];
    }

    // Kiem tra trang thai da vote theo electionId.
    function hasVotedInElection(uint256 electionId, address wallet) external view returns (bool) {
        require(elections[electionId].exists, "Ky bau cu khong ton tai");
        return electionVoted[electionId][wallet];
    }
}
