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
 * @author Chukwubuike Victory Chime a.k.a. yeahChibyke
 * @dev This contract handles the distribution of Hugs tokens via a Merkle Tree-based airdrop
 */
contract HugsAirdrop is EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // >----------> ERRORS
    /// @dev thrown when the provided Merkle proof is invalid
    error HugsAirdrop__InvalidProof();
    /// @dev thrown when an account wants to claim Hugs tokens more than once
    error HugsAirdrop__AlreadyClaimedHugs();
    /// @dev thrown when the provided ECDSA signature is invalid
    error HugsAirdrop__SignatureInvalid();

    // >----------> TYPE DECLARATION
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    // >----------> VARIABLES
    /// @dev array to store addresses of claimers
    address[] private s_claimers;

    /// @dev Merkle root used to validate airdrop claims
    bytes32 private immutable i_merkleRoot;
    /// @dev ERC20 token being airdropped
    IERC20 private immutable i_airdropToken;

    /// @dev mapping to track which addresses have already claimed their airdrop
    mapping(address => bool) public hasClaimedHugs; // I made this public because I want to call it in the test contract

    /// @dev keccak256 hash of the AirdropClaim struct's type signature, used for EIP-712 compliant message signing
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
     * @notice allows eligible users to claim Hugs tokens from the airdrop
     * @dev ensures the user has not previously claimed, verifies the ECDSA signature and the Merkle proof for eligibility
     * @param account address of the account claiming the Hugs tokens
     * @param amount number of Hugs tokens to claim
     * @param merkleProof Merkle proof that confirms the account's eligibility for the airdrop
     * @param v recovery byte of the ECDSA signature
     * @param r first 32 bytes of the ECDSA signature
     * @param s second 32 bytes of the ECDSA signature
     * @notice emits a {HugClaimed} event upon successful claim
     *
     * @custom:error HugsAirdrop__AlreadyClaimedHugs thrown if the account has already claimed Hugs tokens
     * @custom:error HugsAirdrop__SignatureInvalid thrown if the provided ECDSA signature is invalid
     * @custom:error HugsAirdrop__InvalidProof thrown if the provided Merkle proof is invalid
     */
    function claimHugs(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        if (hasClaimedHugs[account]) {
            revert HugsAirdrop__AlreadyClaimedHugs();
        }

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert HugsAirdrop__SignatureInvalid();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert HugsAirdrop__InvalidProof();
        }

        hasClaimedHugs[account] = true;

        s_claimers.push(account);

        emit HugClaimed(account, amount);

        i_airdropToken.safeTransfer(account, amount);
    }

    // >----------> INTERNAL FUNCTIONS
    /**
     * @notice validates the ECDSA signature for the Hugs token claim
     * @dev verifies that the signature provided corresponds to the account's address and message digest
     * @param account address that is expected to have signed the message
     * @param digest hashed message that was signed
     * @param v recovery byte of the signature
     * @param r first 32 bytes of the signature
     * @param s second 32 bytes of the signature
     * @return bool returns true if the signature is valid and was signed by the receiver, otherwise false
     */
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    // >>---------------------->> EXTERNAL & PUBLIC VIEW FUNCTIONS
    /**
     * @notice generates the EIP-712 message digest for a Hugs claim
     * @dev creates a hash of the AirdropClaim struct using the EIP-712 standard for typed structured data
     * @param account address claiming the Hugs token(s)
     * @param amount number of Hugs tokens being claimed
     * @return bytes32 the hashed message that represents the Airdrop claim
     */
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    /// @dev provides the Merkle root stored in the contract, which is used to verify the legitimacy of a claim
    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    /// @dev provides the reference to the ERC20 token contract used for the airdrop
    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function getClaimers() external view returns (address[] memory) {
        return s_claimers;
    }
}
