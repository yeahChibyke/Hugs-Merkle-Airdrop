// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {HugsToken} from "./HugsToken.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract HugsAirdrop {
    using SafeERC20 for IERC20;

    error HugsAirdrop__InvalidProof();
    error HugsAirdrop__AlreadyClaimedHugs();

    address[] claimers;

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    mapping(address => bool) private s_hasClaimedHugs;

    event HugClaimed(address indexed claimer, uint256 indexed amount);

    constructor(bytes32 merkleRoot, IERC20 airdropToken) {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claimHugs(address account, uint256 amount, bytes32[] calldata merkleProof) external {
        if (s_hasClaimedHugs[account]) {
            revert HugsAirdrop__AlreadyClaimedHugs();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert HugsAirdrop__InvalidProof();
        }

        s_hasClaimedHugs[account] = true;

        emit HugClaimed(account, amount);

        i_airdropToken.safeTransfer(account, amount);
    }

    // >>---------------------->> helper functions

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }
}
