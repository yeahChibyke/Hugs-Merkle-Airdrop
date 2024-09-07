// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {HugsToken} from "./HugsToken.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Hugs Airdrop
 * @author Chukwubuike Victory Chime
 * @dev This contract handles the distribution of Hugs tokens via a Merkle Tree-based airdrop
 */
contract HugsAirdrop is EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // >----------> ERRORS
    /// @dev thrown when the provided Merkle proof is invalid
    error HugsAirdrop__InvalidProof();
    /// @dev thrown when an account wants to claim Hugs tokens more than once
    error HugsAirdrop__AlreadyClaimedHugs();
    error HugsAirdrop__SignatureInvalid();

    // >----------> TYPE DECLARATION
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    // >----------> VARIABLES
    /// @dev array to store addresses of claimers
    address[] claimers;

    /// @dev Merkle root used to validate airdrop claims
    bytes32 private immutable i_merkleRoot;
    /// @dev ERC20 token being airdropped
    IERC20 private immutable i_airdropToken;

    /// @dev mapping to track which addresses have already claimed their airdrop
    mapping(address => bool) private s_hasClaimedHugs;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account, uint256 amount)");

    // >----------> EVENTS
    /**
     * @dev emitted when a user successfuly claims Hugs tokens
     * @param claimer address of claimer who claimed Hugs tokens
     * @param amount amount oc tokens claimed
     */
    event HugClaimed(address indexed claimer, uint256 indexed amount);

    // >----------> CONSTRUCTOR
    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("HugsAirdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    // >----------> EXTERNAL FUNCTIONS
    /**
     * @notice & @dev claims Hugs tokens if the caller has a valid Merkle proof
     * @dev reverts if the proof is invalid, or the tokens have already been claimed
     * @param account address of claimer
     * @param amount amount of tokens to claim
     * @param merkleProof Merkle proof to validate the claim
     */
    function claimHugs(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        if (s_hasClaimedHugs[account]) {
            revert HugsAirdrop__AlreadyClaimedHugs();
        }

        // check signature validity
        if (!_isValidSignature(account, getMessage(account, amount), v, r, s)) {
            revert HugsAirdrop__SignatureInvalid();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert HugsAirdrop__InvalidProof();
        }

        s_hasClaimedHugs[account] = true;

        emit HugClaimed(account, amount);

        i_airdropToken.safeTransfer(account, amount);
    }

    // >----------> INTERNAL FUNCTIONS
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    // >>---------------------->> EXTERNAL & PUBLIC VIEW FUNCTIONS
    function getMessage(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    /// @dev returns the Merkle root used for the airdrop
    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    /// @dev returns the ERC20 token being airdropped
    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }
}
