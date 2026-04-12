// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Voting DApp - Hop dong bau cu minh bach
/// @notice Hop dong nay duoc thiet ke de phu hop flow: Admin + Voter, whitelist, state machine.
contract Voting {
    // =========================
    // = Cac kieu du lieu chinh =
    // =========================

    /// @dev Vong doi cuoc bau cu:
    /// Created: vua deploy, duoc phep dang ky cu tri va them ung cu vien.
    /// Voting: da mo cong bau cu, cu tri hop le co the bo phieu.
    /// Ended: da ket thuc, khong cho phep thay doi du lieu bau cu.
    enum State {
        Created,
        Voting,
        Ended
    }

    /// @dev Thong tin mot ung cu vien.
    struct Candidate {
        uint256 id;
        string name;
        string image;
        uint256 voteCount;
    }

    // =========================
    // = Bien trang thai chinh =
    // =========================

    /// @notice Dia chi Admin (nguoi trien khai contract).
    address public admin;

    /// @notice Trang thai hien tai cua cuoc bau cu.
    State public electionState;

    /// @notice Moc thoi gian ket thuc bau cu (unix timestamp).
    uint256 public endTime;

    /// @notice Tong so ung cu vien.
    uint256 public candidatesCount;

    /// @notice Danh sach ung cu vien theo id.
    mapping(uint256 => Candidate) public candidates;

    /// @notice Danh sach cu tri hop le (whitelist).
    mapping(address => bool) public isRegistered;

    /// @notice Danh dau vi da bo phieu hay chua.
    mapping(address => bool) public voters;

    // ===========
    // = Events  =
    // ===========

    /// @dev Log khi dang ky cu tri.
    event VoterRegistered(address indexed voter);

    /// @dev Log khi them ung cu vien.
    event CandidateAdded(uint256 indexed candidateId, string name, string image);

    /// @dev Log khi bat dau bau cu.
    event ElectionStarted(uint256 startTime, uint256 endTime);

    /// @dev Log khi co cu tri bo phieu.
    event VoteCast(address indexed voter, uint256 indexed candidateId);

    /// @dev Log khi ket thuc bau cu.
    event ElectionEnded(uint256 endTime);

    // ==============
    // = Modifiers   =
    // ==============

    /// @dev Chi Admin moi duoc goi.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Chi Admin moi co quyen");
        _;
    }

    /// @dev Chi cho phep goi khi contract o dung trang thai.
    modifier inState(State expected) {
        require(electionState == expected, "Trang thai bau cu khong hop le");
        _;
    }

    // =====================
    // = Constructor       =
    // =====================

    /// @notice Khoi tao contract, gan admin va dat trang thai ban dau.
    constructor() {
        admin = msg.sender;
        electionState = State.Created;
    }

    // ============================================
    // = Admin - Dang ky whitelist cho cu tri      =
    // ============================================

    /// @notice Dang ky mot vi cu tri vao whitelist.
    /// @param _voter Dia chi vi cu tri can dang ky.
    function registerVoter(address _voter) external onlyAdmin inState(State.Created) {
        require(_voter != address(0), "Dia chi vi khong hop le");
        require(!isRegistered[_voter], "Vi da duoc dang ky");

        isRegistered[_voter] = true;
        emit VoterRegistered(_voter);
    }

    /// @notice Dang ky hang loat vi cu tri vao whitelist.
    /// @param _voters Danh sach cac vi can dang ky.
    function registerVoters(address[] calldata _voters) external onlyAdmin inState(State.Created) {
        uint256 length = _voters.length;
        require(length > 0, "Danh sach rong");

        for (uint256 i = 0; i < length; i++) {
            address voterAddr = _voters[i];
            if (voterAddr != address(0) && !isRegistered[voterAddr]) {
                isRegistered[voterAddr] = true;
                emit VoterRegistered(voterAddr);
            }
        }
    }

    // ============================================
    // = Admin - Them ung cu vien                  =
    // ============================================

    /// @notice Them ung cu vien co ten + anh.
    /// @dev Chi them duoc khi electionState = Created.
    function addCandidate(string calldata _name, string calldata _image) external onlyAdmin inState(State.Created) {
        require(bytes(_name).length > 0, "Ten ung cu vien khong duoc rong");

        candidatesCount += 1;
        candidates[candidatesCount] = Candidate({
            id: candidatesCount,
            name: _name,
            image: _image,
            voteCount: 0
        });

        emit CandidateAdded(candidatesCount, _name, _image);
    }

    /// @notice Overload de tuong thich front-end cu chi truyen ten.
    function addCandidate(string calldata _name) external onlyAdmin inState(State.Created) {
        require(bytes(_name).length > 0, "Ten ung cu vien khong duoc rong");

        candidatesCount += 1;
        candidates[candidatesCount] = Candidate({
            id: candidatesCount,
            name: _name,
            image: "",
            voteCount: 0
        });

        emit CandidateAdded(candidatesCount, _name, "");
    }

    // ============================================
    // = Admin - Dieu khien trang thai bau cu      =
    // ============================================

    /// @notice Bat dau bau cu va dat thoi gian dem nguoc theo giay.
    /// @param durationSeconds So giay de mo cong bau cu.
    function startElection(uint256 durationSeconds) external onlyAdmin inState(State.Created) {
        require(candidatesCount > 0, "Chua co ung cu vien");
        require(durationSeconds > 0, "Thoi gian bau cu phai > 0");

        electionState = State.Voting;
        endTime = block.timestamp + durationSeconds;

        emit ElectionStarted(block.timestamp, endTime);
    }

    /// @notice Ket thuc bau cu. Theo nghiep vu, Admin dong cong sau khi het gio.
    function endElection() external onlyAdmin inState(State.Voting) {
        require(block.timestamp >= endTime, "Chua den thoi diem ket thuc");

        electionState = State.Ended;
        emit ElectionEnded(block.timestamp);
    }

    // ============================================
    // = Voter - Bo phieu                          =
    // ============================================

    /// @notice Bo phieu cho mot ung cu vien.
    /// @dev Phai qua 4 cho chan: whitelist, chua vote, dang Voting, chua qua han.
    function vote(uint256 _candidateId) external inState(State.Voting) {
        require(isRegistered[msg.sender], "Vi khong nam trong whitelist");
        require(!voters[msg.sender], "Ban da bo phieu");
        require(block.timestamp <= endTime, "Cuoc bau cu da het gio");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "ID ung cu vien khong hop le");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;

        emit VoteCast(msg.sender, _candidateId);
    }

    // ============================================
    // = View - Doc du lieu cho Front-end          =
    // ============================================

    /// @notice Tra ve danh sach ket qua sau khi da ket thuc bau cu.
    /// @dev Neu muon cho phep xem trong luc dang bau, bo require ben duoi.
    function getResults() external view inState(State.Ended) returns (Candidate[] memory) {
        Candidate[] memory results = new Candidate[](candidatesCount);

        for (uint256 i = 1; i <= candidatesCount; i++) {
            results[i - 1] = candidates[i];
        }

        return results;
    }

    /// @notice Tra ve toan bo danh sach ung cu vien (khong bat buoc da ket thuc).
    /// @dev Ham nay huu ich cho giao dien hien thi danh sach truoc khi vote.
    function getAllCandidates() external view returns (Candidate[] memory) {
        Candidate[] memory items = new Candidate[](candidatesCount);

        for (uint256 i = 1; i <= candidatesCount; i++) {
            items[i - 1] = candidates[i];
        }

        return items;
    }

    /// @notice Tra ve nguoi dang dan dau (co the dung trong qua trinh bau).
    function getWinner() external view returns (string memory name, uint256 votes) {
        uint256 winningVoteCount = 0;
        uint256 winningId = 0;

        for (uint256 i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winningId = i;
            }
        }

        if (winningVoteCount == 0) {
            return ("Chua co ai", 0);
        }

        return (candidates[winningId].name, candidates[winningId].voteCount);
    }
}
