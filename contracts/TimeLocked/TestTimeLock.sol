// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

contract TestTimeLock {
    address public timeLock;

    constructor(address _timelock) {
        timeLock = _timelock;
    }

    function test() external {
        require(msg.sender == timeLock, "not timelock");
    }

    function getTimestamp() external view returns (uint256 timestamp) {
        return block.timestamp + 100;
    }
}
