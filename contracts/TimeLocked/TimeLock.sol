// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

contract TimeLock {
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error TimestampNotInRangeError(uint256 blockTimestamp, uint256 timestamp);
    error NotQueuedError(bytes32 txId);
    error TimeStampNotPassedError(uint256 blockTimestamp, uint256 timstamp);
    error TimeStampExpiredError(uint256 blockTimestamp, uint256 expiresAt);
    error TxFailedError(bytes32 txId);

    address public _owner;
    mapping(bytes32 => bool) public queued;
    uint8 internal constant MIN_DELAY = 10;
    uint16 internal constant MAX_DELAY = 1000;
    uint16 internal constant GRACE_PERIOD = 1000;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert NotOwnerError();
        }
        _;
    }
    event Queued(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string func,
        bytes data,
        uint256 timestamp
    );
    event Executed(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string func,
        bytes data,
        uint256 timestamp
    );
    event Canceled(bytes32 _txid);

    function getTxId(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 timestamp
    ) public pure returns (bytes32 txId) {
        return keccak256(abi.encode(_target, _value, _func, _data, timestamp));
    }

    function queue(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external onlyOwner {
        // create txId
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);
        // check txId is unique
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        // check timestamp
        if (_timestamp < block.timestamp + MIN_DELAY || _timestamp > block.timestamp + MAX_DELAY) {
            revert TimestampNotInRangeError(block.timestamp, _timestamp);
        }
        // queue tx
        queued[txId] = true;
        emit Queued(txId, _target, _value, _func, _data, _timestamp);
    }

    function execute(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external payable onlyOwner returns (bytes memory) {
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);
        // ckeck tx is queued
        if (!queued[txId]) {
            revert NotQueuedError(txId);
        }
        // check block.timestamp > _timestamp
        if (block.timestamp < _timestamp) {
            revert TimeStampNotPassedError(block.timestamp, _timestamp);
        }
        //check if txn is wxecuting in grace_period
        if (block.timestamp > _timestamp + GRACE_PERIOD) {
            revert TimeStampExpiredError(block.timestamp, _timestamp + GRACE_PERIOD);
        }
        // delete txn
        queued[txId] = false;
        // execute txn
        bytes memory data;
        if (bytes(_func).length > 0) {
            data = abi.encodePacked(bytes4(keccak256(bytes(_func))), _data);
        } else {
            data = _data;
        }
        (bool ok, bytes memory res) = _target.call{value: _value}(data);
        if (!ok) {
            revert TxFailedError(txId);
        }
        emit Executed(txId, _target, _value, _func, _data, _timestamp);
        return res;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        if (!queued[_txId]) {
            revert NotQueuedError(_txId);
        }
        queued[_txId] = false;
        emit Canceled(_txId);
    }

    receive() external payable {}
}
