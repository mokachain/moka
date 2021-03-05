pragma solidity ^0.5.12;

import './SafeMath.sol';

library MokaLibrary {
    using SafeMath for uint;
    
    uint private constant USDT_RATE = 1e6;
    
    // min to USDT
    function toUsdt(uint _value) internal pure returns (uint) {
        return _value / USDT_RATE;
    }
    
    // USDT to min
    function usdtTo(uint _value) internal pure returns (uint) {
        return _value.mul(USDT_RATE);
    }
    
    // 计算用户的teamLevel
    function computeTeamLevel(uint _teamMenberNum) internal pure returns (uint _teamLevel) {
        if (_teamMenberNum >= 10 && _teamMenberNum < 20) {
            _teamLevel = 1;
        } else if (_teamMenberNum >= 20 && _teamMenberNum < 30) {
            _teamLevel = 2;
        } else if (_teamMenberNum >= 30 && _teamMenberNum < 50) {
            _teamLevel = 3;
        } else if (_teamMenberNum >= 50 && _teamMenberNum < 100) {
            _teamLevel = 4;
        } else if (_teamMenberNum >= 100 && _teamMenberNum < 200) {
            _teamLevel = 5;
        } else if (_teamMenberNum >= 200 && _teamMenberNum < 300) {
            _teamLevel = 6;
        } else if (_teamMenberNum >= 300 && _teamMenberNum < 500) {
            _teamLevel = 7;
        } else if (_teamMenberNum >= 500 && _teamMenberNum < 1000) {
            _teamLevel = 8;
        } else if (_teamMenberNum >= 1000 && _teamMenberNum < 2000) {
            _teamLevel = 9;
        } else if (_teamMenberNum >= 2000 && _teamMenberNum < 4000) {
            _teamLevel = 10;
        } else if (_teamMenberNum >= 4000 && _teamMenberNum < 6000) {
            _teamLevel = 11;
        } else if (_teamMenberNum >= 6000 && _teamMenberNum < 8000) {
            _teamLevel = 12;
        } else if (_teamMenberNum >= 8000 && _teamMenberNum < 10000) {
            _teamLevel = 13;
        } else if (_teamMenberNum >= 10000 && _teamMenberNum < 30000) {
            _teamLevel = 14;
        } else if (_teamMenberNum >= 30000 && _teamMenberNum < 50000) {
            _teamLevel = 15;
        } else if (_teamMenberNum >= 50000 && _teamMenberNum < 100000) {
            _teamLevel = 16;
        } else if (_teamMenberNum >= 100000 && _teamMenberNum < 200000) {
            _teamLevel = 17;
        } else if (_teamMenberNum >= 200000 && _teamMenberNum < 300000) {
            _teamLevel = 18;
        } else if (_teamMenberNum >= 300000 && _teamMenberNum < 500000) {
            _teamLevel = 19;
        } else if (_teamMenberNum >= 500000) {
            _teamLevel = 20;
        }
    }
    
}
