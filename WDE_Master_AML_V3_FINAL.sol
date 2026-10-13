// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WDE_Master_AML {
    address public owner;
    address public oracleAuthority;
    enum BlockType { NONE, TEMP_30_DAYS, TEMP_90_DAYS, TEMP_1_YEAR, PERMANENT_KICKOUT, RELEASED }
    struct BlacklistInfo { bool isActive; bool permanent; uint256 blockedAt; uint256 blockedUntil; BlockType blockType; string reason; string caseId; address blockedBy; }
    struct FIACase { string caseId; address suspectUser; uint256 totalVotesFor; uint256 totalVotesAgainst; uint256 startTime; uint256 endTime; bool isResolved; BlockType recommendedBlock; }
    mapping(address => BlacklistInfo) public blacklistRegistry;
    mapping(string => FIACase) public fiaCases;
    mapping(string => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public communityMembers;
    event UserBlocked(address indexed user, BlockType blockType, uint256 until, string caseId, string reason);
    event UserReleased(address indexed user, string caseId, string reason);
    event UserPermanentKickout(address indexed user, string caseId);
    modifier onlyOwner() { require(msg.sender==owner,"Only Owner"); _; }
    modifier onlyOracle() { require(msg.sender==oracleAuthority,"Only Oracle"); _; }
    constructor(address _oracle) { owner = msg.sender; oracleAuthority = _oracle; }
    function isBlacklisted(address _user) external view returns (bool) {
        BlacklistInfo memory info = blacklistRegistry[_user];
        if(!info.isActive) return false;
        if(info.permanent) return true;
        if(info.blockedUntil > 0 && block.timestamp > info.blockedUntil) return false;
        return true;
    }
    function getBlacklistStatus(address _user) external view returns (bool active, bool permanent, uint256 until, BlockType bType, string memory reason, uint256 remainingDays) {
        BlacklistInfo memory i = blacklistRegistry[_user];
        uint256 rem = 0;
        if(i.blockedUntil > block.timestamp) rem = (i.blockedUntil - block.timestamp) / 1 days;
        return (i.isActive, i.permanent, i.blockedUntil, i.blockType, i.reason, rem);
    }
    function blockFor30Days(address _user, string memory _caseId, string memory _reason) external onlyOracle {
        blacklistRegistry[_user] = BlacklistInfo(true,false,block.timestamp,block.timestamp+30 days,BlockType.TEMP_30_DAYS,_reason,_caseId,msg.sender);
        emit UserBlocked(_user,BlockType.TEMP_30_DAYS,block.timestamp+30 days,_caseId,_reason);
    }
    function blockFor90Days(address _user, string memory _caseId, string memory _reason) external onlyOracle {
        blacklistRegistry[_user] = BlacklistInfo(true,false,block.timestamp,block.timestamp+90 days,BlockType.TEMP_90_DAYS,_reason,_caseId,msg.sender);
        emit UserBlocked(_user,BlockType.TEMP_90_DAYS,block.timestamp+90 days,_caseId,_reason);
    }
    function blockFor1Year(address _user, string memory _caseId, string memory _reason) external onlyOracle {
        blacklistRegistry[_user] = BlacklistInfo(true,false,block.timestamp,block.timestamp+365 days,BlockType.TEMP_1_YEAR,_reason,_caseId,msg.sender);
        emit UserBlocked(_user,BlockType.TEMP_1_YEAR,block.timestamp+365 days,_caseId,_reason);
    }
    function permanentKickout(address _user, string memory _caseId, string memory _reason) external onlyOwner {
        blacklistRegistry[_user] = BlacklistInfo(true,true,block.timestamp,0,BlockType.PERMANENT_KICKOUT,_reason,_caseId,msg.sender);
        emit UserPermanentKickout(_user,_caseId);
    }
    function releaseUser(address _user, string memory _releaseReason) external onlyOwner {
        BlacklistInfo storage info = blacklistRegistry[_user];
        require(info.isActive,"Not blocked");
        info.isActive = false;
        info.blockType = BlockType.RELEASED;
        emit UserReleased(_user,info.caseId,_releaseReason);
    }
    function autoReleaseIfExpired(address _user) external {
        BlacklistInfo storage info = blacklistRegistry[_user];
        require(info.isActive && !info.permanent,"Not expirable");
        require(block.timestamp > info.blockedUntil,"Still blocked");
        info.isActive = false;
        info.blockType = BlockType.RELEASED;
        emit UserReleased(_user,info.caseId,"Auto expired");
    }
    function finalizeCaseWithBlockType(string memory _caseId, BlockType _bType) external onlyOracle {
        FIACase storage c = fiaCases[_caseId];
        require(!c.isResolved,"Resolved");
        c.isResolved = true;
        c.recommendedBlock = _bType;
        address suspect = c.suspectUser;
        if(_bType==BlockType.TEMP_30_DAYS) this.blockFor30Days(suspect,_caseId,"FIA Voting 30D");
        else if(_bType==BlockType.TEMP_90_DAYS) this.blockFor90Days(suspect,_caseId,"FIA Voting 90D");
        else if(_bType==BlockType.TEMP_1_YEAR) this.blockFor1Year(suspect,_caseId,"FIA Voting 1Y");
        else if(_bType==BlockType.PERMANENT_KICKOUT) this.permanentKickout(suspect,_caseId,"FIA Voting Permanent");
    }
    function setCommunityMember(address _m,bool _s) external onlyOwner { communityMembers[_m]=_s; }
}
