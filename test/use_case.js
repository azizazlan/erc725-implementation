const { toBN, keccak256 } = web3.utils;
const {
    singletons,
    BN,
    ether,
    expectRevert
} = require("@openzeppelin/test-helpers");
const { getEncodedCall, checkErrorRevert } = require("../helpers/utils");

const AccountContract = artifacts.require("ERC725Account");
const SimpleKeyManager = artifacts.require("SimpleKeyManager");

// keccak256("EXECUTOR_ROLE")
const EXECUTOR_ROLE =
    "0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63";
const ERC1271_MAGIC_VALUE = "0x1626ba7e";

contract("ERC725Account", async accounts => {

    // Goverment officer
    const officerPrivateKey = web3.utils.randomHex(32);
    const officerAcc = web3.eth.accounts.privateKeyToAccount(officerPrivateKey)
        .address;

    it("Goverment issue a citizenship claim to a citizen", async () => {
        const govId = await AccountContract.new(accounts[0], { from: accounts[0] });
        const keyManager = await SimpleKeyManager.new(
            govId.address,
            accounts[0],
            {
                from: accounts[0]
            }
        );

        // Appoint the officer to sign on behalf of goverment
        await keyManager.grantRole(EXECUTOR_ROLE, officerAcc, {
            from: accounts[0]
        });

        const dataToSign = "The person has citizenship of this country"; //a claim
        const signedData = web3.eth.accounts.sign(
            dataToSign,
            officerPrivateKey
        );

        // Verify...
        const result = await keyManager.isValidSignature.call(
            signedData.messageHash,
            signedData.signature
        );

        assert.equal(result, ERC1271_MAGIC_VALUE);
    });
});
