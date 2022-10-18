// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Timelock {
    error NotOwnerError();

    uint256 public constant MIN_DELAY = 10; // seconds
    uint256 public constant MAX_DELAY = 1000; // seconds
    uint256 public constant GRACE_PERIOD = 1000; // seconds

    address public owner;
    mapping(bytes32 => bool) public queued;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner");
        _;
    }

    receive() external payable {}

    function getTransactionId(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_target, _value, _func, _data, _timestamp));
    }

    function queue(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external onlyOwner {
        bytes32 txid = getTransactionId(
            _target,
            _value,
            _func,
            _data,
            _timestamp
        );

        require(!queued[txid], "Already queued");

        require(
            _timestamp > block.timestamp + MIN_DELAY &&
                _timestamp < block.timestamp + MAX_DELAY,
            "Out of range time"
        );

        queued[txid] = true;
    }

    function execute(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external payable onlyOwner {
        bytes32 txid = getTransactionId(
            _target,
            _value,
            _func,
            _data,
            _timestamp
        );

        require(queued[txid], "Not queued");

        require(
            _timestamp < block.timestamp &&
                block.timestamp < _timestamp + GRACE_PERIOD,
            "Out of range time"
        );

        queued[txid] = false;
    }

    function cancel(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external onlyOwner {
        bytes32 txid = getTransactionId(
            _target,
            _value,
            _func,
            _data,
            _timestamp
        );

        require(queued[txid], "Not queued");

        bytes memory data;
        if (bytes(_func).length > 0) {
            // data = func selector + _data
            data = abi.encodePacked(bytes4(keccak256(bytes(_func))), _data);
        } else {
            // call fallback with data
            data = _data;
        }

        (bool _ok, ) = _target.call{value: _value}(data);
        require(_ok, "Tx failed");

        queued[txid] = false;
    }
}
