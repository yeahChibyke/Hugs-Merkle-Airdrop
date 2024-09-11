// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {HugsToken} from "../src/HugsToken.sol";
import {HugsAirdrop} from "../src/HugsAirdrop.sol";
import {Test, console2} from "forge-std/Test.sol";
import {DeployHugsAirdrop} from "../script/DeployHugsAirdrop.s.sol";
// import {ZkSyncChainChecker} from "Foundry-Devops/src/ZkSyncChainChecker.sol";

contract TestHugsAirdrop is Test {
    HugsToken token;
    HugsAirdrop airdrop;

    bytes32 ROOT = 0xb1155292a7f465f73a70be41a25a6d7ab8e760cabb68c08072856aa05eb23e32;

    // ------Proofs------ //
    bytes32 proofA1 = 0x960bfc5afe0572f554d1ccc4b594f1f4c5aeccab6bf6cc1d2ca735a70078b61d;
    bytes32 proofA2 = 0x543793e984215b0a24b11f843eea8755b11141397ef712e5af3111067a3019a8;
    bytes32[] aliceProof = [proofA1, proofA2];

    bytes32 proofB1 = 0xb4ad04bfcc1a89a0939f16e689fd17d2435174d8431a765e538b306bebd0438e;
    bytes32 proofB2 = 0x543793e984215b0a24b11f843eea8755b11141397ef712e5af3111067a3019a8;
    bytes32[] bobProof = [proofB1, proofB2];

    bytes32 proofC1 = 0xcc519ead7d2f4eacc153fd8cfade41d33f0fa718fbe454eb2663ae65b2aa6476;
    bytes32 proofC2 = 0xfe8afbaa6b6838916e80bd2f0d376704cfd04a92db59cc177c9b465249678402;
    bytes32[] claraProof = [proofC1, proofC2];

    bytes32 proofD1 = 0x03cb497476aa2616a9542659cef0a92c84e884732e6db563047aa3f0ae9ecd69;
    bytes32 proofD2 = 0xfe8afbaa6b6838916e80bd2f0d376704cfd04a92db59cc177c9b465249678402;
    bytes32[] danProof = [proofD1, proofD2];

    uint256 constant CLAIM_AMOUNT = 25e18;
    uint256 constant SEND_AMOUNT = 100e18;

    // multi users
    address Alice;
    uint256 alicePrvKey;
    address Bob;
    uint256 bobPrvKey;
    address Clara;
    uint256 claraPrvKey;
    address Dan;
    uint256 danPrvKey;

    address gasPayer;

    function setUp() public {
        token = new HugsToken();
        airdrop = new HugsAirdrop(ROOT, token);

        token.mint(token.owner(), SEND_AMOUNT); // mint tokens since initial supply was not specified in the HugsToken contract
        token.transfer(address(airdrop), SEND_AMOUNT); // trasnfer the minted tokens to the airdrop contract, so that the airdrop contract now holds the tokens

        (Alice, alicePrvKey) = makeAddrAndKey("Alice");
        (Bob, bobPrvKey) = makeAddrAndKey("Bob");
        (Clara, claraPrvKey) = makeAddrAndKey("Clara");
        (Dan, danPrvKey) = makeAddrAndKey("Dan");

        gasPayer = makeAddr("gasPayer");
    }

    function testCanClaim() public {
        uint256 initBalOfAlice = token.balanceOf(Alice);
        uint256 tokenInAirdrop = token.balanceOf(address(airdrop));

        bytes32 digest = airdrop.getMessageHash(Alice, CLAIM_AMOUNT);

        // sign a message with Alice private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrvKey, digest);

        vm.prank(gasPayer);
        airdrop.claimHugs(Alice, CLAIM_AMOUNT, aliceProof, v, r, s);

        uint256 currentBalOfAlice = token.balanceOf(Alice);
        uint256 currentTokenInAIrdrop = token.balanceOf(address(airdrop));

        assertEq(currentBalOfAlice - initBalOfAlice, CLAIM_AMOUNT);
        assertEq(currentTokenInAIrdrop, tokenInAirdrop - currentBalOfAlice);
        assert(airdrop.getClaimStatus(Alice) == true);
    }

    function testClaimFailWithInvalidSignature() public {
        uint8 v;
        bytes32 r;
        bytes32 s;

        vm.prank(gasPayer);
        vm.expectRevert(HugsAirdrop.HugsAirdrop__SignatureInvalid.selector);
        airdrop.claimHugs(Alice, CLAIM_AMOUNT, aliceProof, v, r, s);
    }

    function testMultipleClaim() public {
        uint256 initBobBal = token.balanceOf(Bob);
        uint256 initClaraBal = token.balanceOf(Clara);
        uint256 initDanBal = token.balanceOf(Dan);
        uint256 airdropBal = token.balanceOf(address(airdrop));

        assert(initBobBal == 0);
        assert(initClaraBal == 0);
        assert(initDanBal == 0);
        assert(airdropBal == SEND_AMOUNT);

        bytes32 bobDigest = airdrop.getMessageHash(Bob, CLAIM_AMOUNT);
        bytes32 claraDigest = airdrop.getMessageHash(Clara, CLAIM_AMOUNT);
        bytes32 danDigest = airdrop.getMessageHash(Dan, CLAIM_AMOUNT);

        // sign messages with respective  user private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrvKey, bobDigest);
        (uint8 a, bytes32 b, bytes32 c) = vm.sign(claraPrvKey, claraDigest);
        (uint8 x, bytes32 y, bytes32 z) = vm.sign(danPrvKey, danDigest);

        // claim
        vm.startPrank(gasPayer);

        // Bob
        airdrop.claimHugs(Bob, CLAIM_AMOUNT, bobProof, v, r, s);
        uint256 finalBobBal = token.balanceOf(Bob);
        uint256 airdropBalAfterBobClaim = token.balanceOf(address(airdrop));
        assert(finalBobBal == CLAIM_AMOUNT);
        assert(airdropBal > airdropBalAfterBobClaim);
        assert(airdrop.getClaimStatus(Bob) == true);

        // Clara
        airdrop.claimHugs(Clara, CLAIM_AMOUNT, claraProof, a, b, c);
        uint256 finalClaraBal = token.balanceOf(Clara);
        uint256 airdropBalAfterClaraClaim = token.balanceOf(address(airdrop));
        assert(finalClaraBal == CLAIM_AMOUNT);
        assert(airdropBalAfterBobClaim > airdropBalAfterClaraClaim);
        assert(airdrop.getClaimStatus(Clara) == true);

        // Dan
        airdrop.claimHugs(Dan, CLAIM_AMOUNT, danProof, x, y, z);
        uint256 finalDanBal = token.balanceOf(Dan);
        uint256 airdropBalAfterDanClaim = token.balanceOf(address(airdrop));
        assert(finalDanBal == CLAIM_AMOUNT);
        assert(airdropBalAfterClaraClaim > airdropBalAfterDanClaim);
        assert(airdrop.getClaimStatus(Dan) == true);

        vm.stopPrank();
    }

    function testRepeatClaimWillFail() public {
        uint256 initAliceBal = token.balanceOf(Alice);
        uint256 airdropBalBeforeAliceFirstClaim = token.balanceOf(address(airdrop));

        assertEq(initAliceBal, 0);
        assertEq(airdropBalBeforeAliceFirstClaim, SEND_AMOUNT);

        bytes32 digest = airdrop.getMessageHash(Alice, CLAIM_AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrvKey, digest);

        vm.prank(gasPayer);
        airdrop.claimHugs(Alice, CLAIM_AMOUNT, aliceProof, v, r, s);
        uint256 finalAliceBal = token.balanceOf(Alice);
        uint256 airdropBalAfterAliceSuccessClaim = token.balanceOf(address(airdrop));

        assert(finalAliceBal > initAliceBal);
        assert(finalAliceBal == CLAIM_AMOUNT);
        assert(airdropBalBeforeAliceFirstClaim > airdropBalAfterAliceSuccessClaim);
        assertEq(airdropBalBeforeAliceFirstClaim - airdropBalAfterAliceSuccessClaim, CLAIM_AMOUNT);

        // Try to claim again
        vm.prank(gasPayer);
        vm.expectRevert(HugsAirdrop.HugsAirdrop__AlreadyClaimedHugs.selector);
        airdrop.claimHugs(Alice, CLAIM_AMOUNT, aliceProof, v, r, s);

        uint256 balOfAliceAfterFailClaim = token.balanceOf(Alice);
        uint256 airdropBalAfterAliceFailClaim = token.balanceOf(address(airdrop));

        assert(balOfAliceAfterFailClaim == finalAliceBal);
        assert(airdropBalAfterAliceSuccessClaim == airdropBalAfterAliceFailClaim);
    }
}
