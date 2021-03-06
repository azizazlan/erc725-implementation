// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

// interfaces
import "erc725/contracts/IERC1271.sol";
import "erc725/contracts/ERC725/IERC725X.sol";

// modules
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// libraries
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SimpleKeyManager is ERC165, IERC1271, AccessControl {
    using ECDSA for bytes32;
    using SafeMath for uint256;

    bytes4 internal constant _INTERFACE_ID_ERC1271 = 0x1626ba7e;
    bytes4 internal constant _ERC1271FAILVALUE = 0xffffffff;

    // keccak256("EXECUTOR_ROLE")
    bytes32
        public constant EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63;

    IERC725X public Account;
    mapping(address => uint256) private _nonceStore;

    // EVENTS
    event Executed(uint256 indexed _value, bytes _data);

    constructor(address _account, address _newOwner) public {
        // make owner an executor
        _setupRole(DEFAULT_ADMIN_ROLE, _newOwner);
        _setupRole(EXECUTOR_ROLE, _newOwner);

        // Link account
        Account = IERC725X(_account);

        _registerInterface(_INTERFACE_ID_ERC1271);
    }

    function getNonce(address _address) public view returns (uint256) {
        return _nonceStore[_address];
    }

    function execute(bytes memory _data) external payable {
        require(
            hasRole(EXECUTOR_ROLE, _msgSender()),
            "Only executors are allowed"
        );

        (bool success, ) = address(Account).call{
            value: msg.value,
            gas: gasleft()
        }(_data); //(success, ) =
        if (!success) revert();
        emit Executed(msg.value, _data);
    }

    // allows anybody to execute given they have a signed messaged from an executor
    function executeRelayedCall(
        address signedFor,
        bytes memory _data,
        uint256 _nonce,
        bytes memory _signature
    ) external {
        require(
            signedFor == address(this),
            "Message not signed for this keyManager"
        );

        bytes memory blob = abi.encodePacked(
            address(this), // needs to be signed for this keyManager
            _data,
            _nonce // Prevents replays
        );

        // recover the signer
        address from = keccak256(blob).toEthSignedMessageHash().recover(
            _signature
        );

        require(hasRole(EXECUTOR_ROLE, from), "Only executors are allowed");
        require(_nonceStore[from] == _nonce, "Incorrect nonce");

        // increase the nonce
        _nonceStore[from] = _nonceStore[from].add(1);

        (bool success, ) = address(Account).call{ value: 0, gas: gasleft() }(
            _data
        ); //(success, ) =
        if (!success) revert();
        emit Executed(0, _data);
    }

    /**
     * @notice Checks if an owner signed `_data`.
     * ERC1271 interface.
     *
     * @param _hash hash of the data signed//Arbitrary length data signed on the behalf of address(this)
     * @param _signature owner's signature(s) of the data
     */
    function isValidSignature(bytes32 _hash, bytes memory _signature)
        public
        override
        view
        returns (bytes4 magicValue)
    {
        address recoveredAddress = ECDSA.recover(_hash, _signature);

        return
            (hasRole(EXECUTOR_ROLE, recoveredAddress) ||
                hasRole(DEFAULT_ADMIN_ROLE, recoveredAddress))
                ? _INTERFACE_ID_ERC1271
                : _ERC1271FAILVALUE;
    }
}
