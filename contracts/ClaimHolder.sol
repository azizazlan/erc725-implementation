// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "erc725/contracts/ERC725/ERC725Account.sol";
import "erc725/contracts/ERC734/ERC734KeyManager.sol";

contract ClaimHolder is ERC725Account, ERC734KeyManager {
    event Created();

    constructor(address _newOwner)
        public
        ERC725Account(_newOwner)
        ERC734KeyManager()
    {
        initialize();
        emit Created();
    }
}
