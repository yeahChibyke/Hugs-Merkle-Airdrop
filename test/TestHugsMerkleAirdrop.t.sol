// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {HugsToken} from "../src/HugsToken.sol";
import {HugsAirdrop} from "../src/HugsAirdrop.sol";
import {Test, console2} from "forge-std/Test.sol";
import {DeployHugsAirdrop} from "../script/DeployHugsAirdrop.s.sol";
import {ZkSyncChainChecker} from "Foundry-Devops/src/ZkSyncChainChecker.sol";

contract TestHugsAirdrop is ZkSyncChainChecker, Test {
    HugsToken token;
    HugsAirdrop airdrop;

    bytes32 ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;

    bytes32 proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] PROOF = [proofOne, proofTwo];

    address user;
    uint256 userPrvKey;
    uint256 constant CLAIM_AMOUNT = 25e18;
    uint256 constant SEND_AMOUNT = 100e18;

    address gasPayer;

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployHugsAirdrop deployer = new DeployHugsAirdrop();
            (airdrop, token) = deployer.deployHugsAirdrop();
        } else {
            token = new HugsToken();
            airdrop = new HugsAirdrop(ROOT, token);

            token.mint(token.owner(), SEND_AMOUNT); // mint tokens since initial supply was not specified in the HugsToken contract
            token.transfer(address(airdrop), SEND_AMOUNT); // trasnfer the minted tokens to the airdrop contract, so that the airdrop contract now holds the tokens
        }

        (user, userPrvKey) = makeAddrAndKey("user");

        gasPayer = makeAddr("gasPayer");
    }

    function testUserCanClaim() public {
        uint256 initBalOfUser = token.balanceOf(user);
        uint256 tokensInAirDrop = token.balanceOf(address(airdrop));

        bytes32 digest = airdrop.getMessageHash(user, CLAIM_AMOUNT);

        //  sign a message with user private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrvKey, digest);

        vm.prank(gasPayer); // gaspayer calls the claimHugs function using signed message
        airdrop.claimHugs(user, CLAIM_AMOUNT, PROOF, v, r, s);

        uint256 currentBalOfUser = token.balanceOf(user);

        uint256 remTokensInAirDrop = token.balanceOf(address(airdrop));

        assertEq(currentBalOfUser - initBalOfUser, CLAIM_AMOUNT);
        assertEq(remTokensInAirDrop, tokensInAirDrop - currentBalOfUser);
    }

    function testClaimFailWithInvalidSignedMessage() public {
        uint8 v;
        bytes32 r;
        bytes32 s;

        vm.prank(gasPayer);
        vm.expectRevert(HugsAirdrop.HugsAirdrop__SignatureInvalid.selector);
        airdrop.claimHugs(user, CLAIM_AMOUNT, PROOF, v, r, s);
    }
}
