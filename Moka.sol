pragma solidity ^0.5.12;

import './libraries/SafeMath.sol';
import './libraries/MokaLibrary.sol';
import './interfaces/ITRC20.sol';

contract Moka {
    using SafeMath for uint;
    // TODO
    address public constant USDT_ADDR = address(0x41A614F803B6FD780986A42C78EC9C7F77E6DED13C);
    address public owner;
    // TODO
    uint private constant WHEEL_TIME = 10*24*60*60;
    // uint private constant WHEEL_TIME = 1*60;
    
    constructor(address _owner) public {
        owner = _owner;
    }
    
    // 用户信息
    struct Player {
        uint id;                            // 用户id
        address addr;                       // 用户地址
        uint referrerId;                    // 推荐人(上一级)id：0表示没有推荐人(上一级)
        uint[] oneFriends;                  // 1代好友列表，存放的是id
        uint[] orderIds;                    // 所有订单id
        uint wheelNum;                      // 用户的轮数(第几轮)，每一轮只能投资一次，所以轮数也等于用户的总订单数
        uint totalAmt;                      // 用户的总投资额
        uint uBalance;                      // 用户的可提现余额
        uint teamMemberNum;                 // 用户的团队的有效成员数
        uint teamLevel;                     // 团队等级
        uint teamProfit;                    // 团队总收益
        uint teamAmt;                       // 团队业绩
        uint dyAmt;                       // 动态总收益dy
        uint[] profitAmts;            
    }
    uint public playerCount;                // 用户id，自增长
    mapping(address => uint) public playerAddrMap;    // 用户地址 => 用户id
    mapping(uint => Player) public playerMap;         // 用户id => 用户信息
    
    struct Order {
        uint id;                // 订单id
        uint playerId;          // 用户id
        uint orderAmt;          // 订单金额
        uint status;            // 订单状态(0进行中，2已返回(订单已结束))
        uint time;
    }
    uint public orderCount;                 // 订单id，自增长
    mapping(uint => Order) public orderMap; // 订单id => 订单信息
    
    uint public total;     // 所有用户的总投资额
    event Withdraw(address indexed _msgSender, uint _value);
    event Buy(address indexed _msgSender, uint _value, address _referrerAddr);
    
    function getOneFriends() external view returns (uint[] memory) {
        return getOneFriendsById(playerAddrMap[msg.sender]);
    }
    
    function getOneFriendsById(uint _id) public view returns (uint[] memory) {
        return playerMap[_id].oneFriends;
    }
    
    function getOrderIds() external view returns (uint[] memory) {
        return getOrderIdsById(playerAddrMap[msg.sender]);
    }
    
    function getOrderIdsById(uint _id) public view returns (uint[] memory) {
        return playerMap[_id].orderIds;
    }
    
    function getProfitAmtsById(uint _id) public view returns (uint[] memory) {
        return playerMap[_id].profitAmts;
    }
    
    function buy(uint _amount, address _referrerAddr) lock external {
        // 减去2%的手续费即是投资额
        uint _value = _amount.mul(100)/102;
        require(_value >= MokaLibrary.usdtTo(200));
        require(_value % MokaLibrary.usdtTo(100) == 0);
        require(ITRC20(USDT_ADDR).transferFrom(msg.sender, address(this), _amount));
        ITRC20(USDT_ADDR).transfer(owner, _amount.sub(_value));
        
        uint _id = _register(msg.sender);
        // 如果不是第一轮，则本次的投资额要大于等于上一次的投资额
        _wheelNumJudge(_id, _value, playerMap[_id].wheelNum);
        
        if (msg.sender != _referrerAddr) {
            _saveReferrerInfo(_id, _referrerAddr);  // 保存推荐人信息
        }
        
        uint _orderId = _saveOrder(_id, _value);
        playerMap[_id].orderIds.push(_orderId);
        playerMap[_id].totalAmt = playerMap[_id].totalAmt.add(_value);
        
        // 计算上级用户的动态奖
        _computeSuperiorUserDynamicAwartAmt(_id, _value);
        // 计算上级用户的团队奖
        _computeSuperiorUserTeamAwartAmt(_id, playerMap[_id].teamLevel, 
            _amount.sub(_value), playerMap[_id].wheelNum, 0, _id, _value);
        
        playerMap[_id].wheelNum++;
        total = total.add(_value);
        emit Buy(msg.sender, _value, _referrerAddr);
    }
    
    // 计算上级用户的团队奖
    function _computeSuperiorUserTeamAwartAmt(
        uint _id, 
        uint _biggestTeamLevel, 
        uint _fee, 
        uint _wheelNum,
        uint _count,
        uint _playerId,
        uint _playerValue
    ) private {
        uint _referrerId = playerMap[_id].referrerId;
        if (_referrerId == 0) {
            return;
        }
        if (_count >= 2000) {
            return;
        }
        uint _teamLevel = playerMap[_referrerId].teamLevel;
        if (_wheelNum == 0) { // 表示是个新用户
            playerMap[_referrerId].teamMemberNum++;
            // 计算用户的teamLevel
            uint _teamLevel2 = MokaLibrary.computeTeamLevel(playerMap[_referrerId].teamMemberNum);
            if (_teamLevel2 > _teamLevel) {
                // _teamLevel = _teamLevel2;
                playerMap[_referrerId].teamLevel = _teamLevel2;
            }
        }
        if (_teamLevel > _biggestTeamLevel) {
            uint _amount = _fee.mul(_teamLevel.sub(_biggestTeamLevel)).mul(5)/100;
            _addBalance(_referrerId, _amount);
            playerMap[_referrerId].teamProfit = playerMap[_referrerId].teamProfit.add(_amount);
            _biggestTeamLevel = _teamLevel;
        }
        playerMap[_referrerId].teamAmt = playerMap[_referrerId].teamAmt.add(_playerValue);
        _count++;
        _computeSuperiorUserTeamAwartAmt(_referrerId, _biggestTeamLevel, _fee, _wheelNum, _count, _playerId, _playerValue);
    }
    
    
    
    // 计算上级用户的动态奖
    function _computeSuperiorUserDynamicAwartAmt(uint _id, uint _value) private {
        // 用户的一级直推人
        uint _referrerId = playerMap[_id].referrerId;
        if (_referrerId > 0) {
            if (playerMap[_id].profitAmts.length == 0) {
                playerMap[_id].profitAmts = new uint[](2);
            }
            
            uint _baseAmt1 = _value;
            // uint _totalAmt1 = playerMap[_referrerId].totalAmt;
            uint[] memory _orderIds = playerMap[_referrerId].orderIds;
            uint _totalAmt1 = orderMap[_orderIds[_orderIds.length - 1]].orderAmt;
            if (_baseAmt1 > _totalAmt1) {
                _baseAmt1 = _totalAmt1;
            }
            uint _amount1 = _baseAmt1.mul(5)/100;
            playerMap[_id].profitAmts[0] = _amount1;
            _addBalance(_referrerId, _amount1);
            playerMap[_referrerId].dyAmt = playerMap[_referrerId].dyAmt.add(_amount1);
            
            // 用户的二级直推人
            uint _referrerId2 = playerMap[_referrerId].referrerId;
            if (_referrerId2 > 0) {
                uint _baseAmt2 = _value;
                // uint _totalAmt2 = playerMap[_referrerId2].totalAmt;
                uint[] memory _orderIds2 = playerMap[_referrerId2].orderIds;
                uint _totalAmt2 = orderMap[_orderIds2[_orderIds2.length - 1]].orderAmt;
                if (_baseAmt2 > _totalAmt2) {
                    _baseAmt2 = _totalAmt2;
                }
                uint _amount2 = _baseAmt2.mul(2)/100;
                playerMap[_id].profitAmts[1] = _amount2;
                _addBalance(_referrerId2, _amount2);
                playerMap[_referrerId2].dyAmt = playerMap[_referrerId2].dyAmt.add(_amount2);
            }
        }
    }
    
    // 如果不是第一轮，则本次的投资额要大于等于上一次的投资额
    function _wheelNumJudge(uint _id, uint _value, uint _wheelNum) private {
        if (_wheelNum == 0) {
            require(_value <= MokaLibrary.usdtTo(5000));
        } else {
            if (_wheelNum == 1) {
                require(_value <= MokaLibrary.usdtTo(20000));
            } else {
                require(_value <= MokaLibrary.usdtTo(50000));
            }
            uint[] memory _orders = playerMap[_id].orderIds;
            require(_orders.length == _wheelNum);
            uint _lastOrderId = _orders[_orders.length - 1]; // 需要结算的订单
            require(_value >= orderMap[_lastOrderId].orderAmt);
            require(block.timestamp >= orderMap[_lastOrderId].time.add(WHEEL_TIME));
            
            // 结算用户的上一笔订单
            orderMap[_lastOrderId].status = 2;
            uint _amount = orderMap[_lastOrderId].orderAmt.mul(115)/100;
            if (_wheelNum > 8) {
                _amount = orderMap[_lastOrderId].orderAmt.mul(113)/100;
            }
            ITRC20(USDT_ADDR).transfer(playerMap[_id].addr, _amount);
        }
    }
    
    
    // 保存订单信息
    function _saveOrder(uint _playerId, uint _value) internal returns(uint) {
        orderCount ++;
        uint _orderId = orderCount;
        orderMap[_orderId] = Order(_orderId, _playerId, _value, 0, block.timestamp);
        return _orderId;
    }
    
    // 保存推荐人信息
    function _saveReferrerInfo(uint _id, address _referrerAddr) internal {
        uint _referrerId = playerAddrMap[_referrerAddr];
        // playerMap[_id].allCirculationAmt == 0 这个条件是为了防止形成邀请关系的闭环
        if (_referrerId > 0 && playerMap[_id].referrerId == 0 && playerMap[_id].totalAmt == 0) {
            playerMap[_id].referrerId = _referrerId;
            playerMap[_referrerId].oneFriends.push(_id);
        }
    }
    
    // 注册
    function _register(address _sender) internal returns (uint _id) {
        _id = playerAddrMap[_sender];
        if (_id == 0) {   // 未注册
            playerCount++;
            _id = playerCount;
            playerAddrMap[_sender] = _id;
            playerMap[_id].id = _id;
            playerMap[_id].addr = _sender;
        }
    }
    
    function _addBalance(uint _id, uint _value) private {
        playerMap[_id].uBalance = playerMap[_id].uBalance.add(_value);
    }
    
    function withdraw() external returns (bool flag) {
        uint _id = playerAddrMap[msg.sender];
        require(_id > 0, "user is not exist");
        uint _uBalance = playerMap[_id].uBalance;
        require(_uBalance > 0, "Insufficient balance");
        playerMap[_id].uBalance = 0;
        playerMap[_id].teamProfit = 0;
        playerMap[_id].dyAmt = 0;
        ITRC20(USDT_ADDR).transfer(msg.sender, _uBalance);
        flag = true;
        emit Withdraw(msg.sender, _uBalance);
    }
    
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    modifier isOwner() {
        require(msg.sender == owner, "is not owner");
        _;
    }
    
    function setOwner(address _addr) external isOwner {
        owner = _addr;
    }
}
