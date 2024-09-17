// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {HugsAirdrop} from "../src/HugsAirdrop.sol";
import {HugsToken} from "../src/HugsToken.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployHugsAirdrop is Script {
    // bytes32 private s_merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    bytes32 private s_merkleRoot = 0xb1155292a7f465f73a70be41a25a6d7ab8e760cabb68c08072856aa05eb23e32;
    uint256 constant MINT_AMOUNT = 100e18;

    function deployHugsAirdrop() public returns (HugsAirdrop, HugsToken) {
        vm.startBroadcast();

        HugsToken token = new HugsToken();
        HugsAirdrop aidrop = new HugsAirdrop(s_merkleRoot, IERC20(address(token)));

        token.mint(token.owner(), MINT_AMOUNT);
        token.transfer(address(aidrop), MINT_AMOUNT);

        vm.stopBroadcast();

        return (aidrop, token);
    }

    function run() external returns (HugsAirdrop, HugsToken) {
        return deployHugsAirdrop();
    }
}
