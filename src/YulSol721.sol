// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// `bytes4(keccak256("ERC721NonexistentToken(uint256)"))`
bytes32 constant nonexistentTokenSelector = 0x7e27328900000000000000000000000000000000000000000000000000000000;
// `bytes4(keccak256("ERC721InvalidReceiver(address)"))`
bytes32 constant invalidReceiverSelector = 0x64a0ae9200000000000000000000000000000000000000000000000000000000;
// `bytes4(keccak256("ERC721AccessDenied()"))`
bytes32 constant accessDeniedSelector = 0x43df7c0200000000000000000000000000000000000000000000000000000000;
// `bytes4(keccak256("ERC721InvalidAddress(address)"))`
bytes32 constant invalidAddressSelector = 0x46cce84100000000000000000000000000000000000000000000000000000000;
// `bytes4(keccak256("ERC721MintLimit()"))`
bytes32 constant mintLimitSelector = 0x3ca6616800000000000000000000000000000000000000000000000000000000;
// `bytes4(keccak256("ERC721MaxSupplyLimit()"))`
bytes32 constant maxSupplyLimitSelector = 0x96c2a07600000000000000000000000000000000000000000000000000000000;

// `keccak256("Transfer(address,address,uint256)")`
bytes32 constant transferEventHash = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
// `keccak256("Approval(address,address,uint256)")`
bytes32 constant approvalEventHash = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
// `keccak256("ApprovalForAll(address,address,bool)")`
bytes32 constant approvalForAllEventHash = 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;

bytes4 constant erc165InterfaceId = 0x01ffc9a7;
bytes4 constant erc721InterfaceId = 0x80ac58cd;

// bytes4(keccak256("onERC721Received(address,address,uint256,bytes"))
bytes32 constant onERC721ReceivedSelector = 0x150b7a0200000000000000000000000000000000000000000000000000000000;

contract YulSol721 {
    uint256 public maxSupply;
    uint256 public nextId = 0;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => uint256) private _mintCount;

    // keccak256(operator, keccak256(owner, slot))
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721InvalidReceiver(address receiver);
    error ERC721AccessDenied();
    error ERC721InvalidAddress(address receiver);
    error ERC721MintLimit();
    error ERC721MaxSupplyLimit();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() {
        maxSupply = 1024;
    }

    function name() external returns (string memory) {
        return "Yul 721";
    }

    function symbol() external returns (string memory) {
        return "YUL";
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        assembly {
            if eq(interfaceId, erc165InterfaceId) {
                mstore(0x00, 1)
                return(0x00, 0x20)
            }

            if eq(interfaceId, erc721InterfaceId) {
                mstore(0x00, 1)
                return(0x00, 0x20)
            }

            mstore(0x00, 0)
            return(0x00, 0x20)
        }
    }

    function totalSupply() external view returns (uint256) {
        assembly {
            mstore(0x00, sload(nextId.slot))
            return(0x00, 0x20)
        }
    }

    function balanceOf(address _account) external view returns (uint256) {
        assembly {
            if eq(_account, 0) {
                mstore(0x00, invalidAddressSelector)
                mstore(0x04, _account)
                revert(0x00, 0x24)
            }

            let memptr := mload(0x40)

            mstore(memptr, _account)
            mstore(add(memptr, 0x20), _balances.slot)
            let balanceHash := keccak256(memptr, 0x40)

            let accountBalance := sload(balanceHash)
            mstore(0x00, accountBalance)
            return(0x00, 0x20)
        }
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        assembly {
            let memptr := mload(0x40)
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)
            mstore(0x00, sload(keccak256(memptr, 0x40)))
            return(0x00, 0x20)
        }
    }

    function mint() external {
        assembly {
            let memptr := mload(0x40)

            // check maxSupply
            if eq(sload(nextId.slot), sload(maxSupply.slot)) {
                mstore(0x00, maxSupplyLimitSelector)
                revert(0x00, 0x04)
            }

            // check mintLimit
            mstore(memptr, caller())
            mstore(add(memptr, 0x20), _mintCount.slot)
            let mintCountHash := keccak256(memptr, 0x40)

            let mintCount := sload(mintCountHash)
            if gt(mintCount, 1) {
                mstore(0x00, mintLimitSelector)
                revert(0x00, 0x04)
            }

            // increment _mintCount
            sstore(mintCountHash, add(mintCount, 1))

            // increment nextId
            let nextIdVal := sload(nextId.slot)
            sstore(nextId.slot, add(nextIdVal, 1))

            // update _owners
            mstore(memptr, nextIdVal)
            mstore(add(memptr, 0x20), _owners.slot)
            sstore(keccak256(memptr, 0x40), caller())

            // update _balances
            mstore(memptr, caller())
            mstore(add(memptr, 0x20), _balances.slot)
            let balanceHash := keccak256(memptr, 0x40)
            sstore(balanceHash, add(sload(balanceHash), 1))

            // emit Transfer
            log4(0, 0, transferEventHash, 0, caller(), nextIdVal)
        }
    }

    function approve(address _to, uint256 _tokenId) external {
        assembly {
            let memptr := mload(0x40)
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)

            if iszero(eq(sload(keccak256(memptr, 0x40)), caller())) {
                mstore(0x00, accessDeniedSelector)
                revert(0x00, 0x04)
            }

            // update _tokenApprovals
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _tokenApprovals.slot)
            sstore(keccak256(memptr, 0x40), _to)

            // emit Approval
            log4(0, 0, approvalEventHash, caller(), _to, _tokenId)
        }
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        assembly {
            let memptr := mload(0x40)

            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)
            let owner := sload(keccak256(memptr, 0x40))

            if eq(owner, 0) {
                mstore(0x00, nonexistentTokenSelector)
                mstore(0x04, _tokenId)
                revert(0x00, 0x24)
            }

            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _tokenApprovals.slot)
            mstore(0x00, sload(keccak256(memptr, 0x40)))
            return(0x00, 0x20)
        }
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        assembly {
            let memptr := mload(0x40)
            mstore(memptr, caller())
            mstore(add(memptr, 0x20), _operatorApprovals.slot)
            let operatorApprovalInnerHash := keccak256(memptr, 0x40)
            mstore(memptr, _operator)
            mstore(add(memptr, 0x20), operatorApprovalInnerHash)
            sstore(keccak256(memptr, 0x40), _approved)

            // emit ApprovalForAll
            mstore(0x00, _approved)
            log3(0x00, 0x20, approvalForAllEventHash, caller(), _operator)
        }
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        assembly {
            let memptr := mload(0x40)

            mstore(memptr, _owner)
            mstore(add(memptr, 0x20), _operatorApprovals.slot)
            let operatorApprovalInnerHash := keccak256(memptr, 0x40)
            mstore(memptr, _operator)
            mstore(add(memptr, 0x20), operatorApprovalInnerHash)
            mstore(0x00, sload(keccak256(memptr, 0x40)))
            return(0x00, 0x20)
        }
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        assembly {
            if eq(_to, 0) {
                mstore(0x00, invalidReceiverSelector)
                mstore(0x04, _to)
                revert(0x00, 0x24)
            }

            let memptr := mload(0x40)

            // check owner
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)
            let ownerHash := keccak256(memptr, 0x40)
            let owner := sload(ownerHash)
            let isOwner := eq(owner, caller())

            if iszero(isOwner) {
                // check _tokenApprovals
                mstore(memptr, _tokenId)
                mstore(add(memptr, 0x20), _tokenApprovals.slot)

                if iszero(eq(caller(), sload(keccak256(memptr, 0x40)))) {
                    // check _operatorApprovals
                    mstore(memptr, owner)
                    mstore(add(memptr, 0x20), _operatorApprovals.slot)
                    let operatorApprovalInnerHash := keccak256(memptr, 0x40)
                    mstore(memptr, caller())
                    mstore(add(memptr, 0x20), operatorApprovalInnerHash)

                    if iszero(sload(keccak256(memptr, 0x40))) {
                        mstore(0x00, accessDeniedSelector)
                        revert(0x00, 0x04)
                    }
                }
            }

            // update _from _balances
            mstore(memptr, _from)
            mstore(add(memptr, 0x20), _balances.slot)
            let fromBalanceHash := keccak256(memptr, 0x40)
            sstore(fromBalanceHash, sub(sload(fromBalanceHash), 1))

            // update _to _balances
            mstore(memptr, _to)
            mstore(add(memptr, 0x20), _balances.slot)
            let toBalanceHash := keccak256(memptr, 0x40)
            sstore(toBalanceHash, add(sload(toBalanceHash), 1))

            // update _owners
            sstore(ownerHash, _to)

            // emit Transfer
            log4(0, 0, transferEventHash, _from, _to, _tokenId)
        }
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata) external {
        assembly {
            // cannot transfer to zero address

            if eq(_to, 0) {
                mstore(0x00, invalidReceiverSelector)
                mstore(0x04, _to)
                revert(0x00, 0x24)
            }

            // check callback
            let memptr := mload(0x40)
            mstore(0x00, onERC721ReceivedSelector)
            mstore(add(0x00, 0x04), caller())
            mstore(add(0x14, 0x10), caller())
            mstore(add(0x34, 0x10), _tokenId)
            calldatacopy(0x70, 0x70, 0x20)

            if iszero(eq(extcodesize(_to), 0)) {
                if iszero(call(gas(), _to, 0, 0, 0xa4, 0x00, 0x20)) {
                    mstore(0x00, invalidReceiverSelector)
                    mstore(0x04, _to)
                    revert(0x00, 0x24)
                }

                if iszero(eq(mload(0x00), onERC721ReceivedSelector)) {
                    mstore(0x00, invalidReceiverSelector)
                    mstore(0x04, _to)
                    revert(0x00, 0x24)
                }
            }

            // check owner
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)
            let ownerHash := keccak256(memptr, 0x40)
            let owner := sload(ownerHash)
            let isOwner := eq(owner, caller())

            if iszero(isOwner) {
                // check _tokenApprovals
                mstore(memptr, _tokenId)
                mstore(add(memptr, 0x20), _tokenApprovals.slot)

                if iszero(eq(caller(), sload(keccak256(memptr, 0x40)))) {
                    // check _operatorApprovals
                    mstore(memptr, owner)
                    mstore(add(memptr, 0x20), _operatorApprovals.slot)
                    let operatorApprovalInnerHash := keccak256(memptr, 0x40)
                    mstore(memptr, caller())
                    mstore(add(memptr, 0x20), operatorApprovalInnerHash)

                    if iszero(sload(keccak256(memptr, 0x40))) {
                        mstore(0x00, accessDeniedSelector)
                        revert(0x00, 0x04)
                    }
                }
            }

            // update _from _balances
            mstore(memptr, _from)
            mstore(add(memptr, 0x20), _balances.slot)
            let fromBalanceHash := keccak256(memptr, 0x40)
            sstore(fromBalanceHash, sub(sload(fromBalanceHash), 1))

            // update _to _balances
            mstore(memptr, _to)
            mstore(add(memptr, 0x20), _balances.slot)
            let toBalanceHash := keccak256(memptr, 0x40)
            sstore(toBalanceHash, add(sload(toBalanceHash), 1))

            // update _owners
            sstore(ownerHash, _to)

            // emit Transfer
            log4(0, 0, transferEventHash, _from, _to, _tokenId)
        }
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        assembly {
            if eq(_to, 0) {
                mstore(0x00, invalidReceiverSelector)
                mstore(0x04, _to)
                revert(0x00, 0x24)
            }

            let memptr := mload(0x40)
            mstore(0x00, onERC721ReceivedSelector)
            mstore(add(0x00, 0x04), caller())
            mstore(add(0x14, 0x10), caller())
            mstore(add(0x34, 0x10), _tokenId)
            mstore(0x64, 0x80)

            if iszero(eq(extcodesize(_to), 0)) {
                if iszero(call(gas(), _to, 0, 0, 0xa4, 0x00, 0x20)) {
                    mstore(0x00, invalidReceiverSelector)
                    mstore(0x04, _to)
                    revert(0x00, 0x24)
                }

                if iszero(eq(mload(0x00), onERC721ReceivedSelector)) {
                    mstore(0x00, invalidReceiverSelector)
                    mstore(0x04, _to)
                    revert(0x00, 0x24)
                }
            }

            // check owner
            mstore(memptr, _tokenId)
            mstore(add(memptr, 0x20), _owners.slot)
            let ownerHash := keccak256(memptr, 0x40)
            let owner := sload(ownerHash)
            let isOwner := eq(owner, caller())

            if iszero(isOwner) {
                // check _tokenApprovals
                mstore(memptr, _tokenId)
                mstore(add(memptr, 0x20), _tokenApprovals.slot)

                if iszero(eq(caller(), sload(keccak256(memptr, 0x40)))) {
                    // check _operatorApprovals
                    mstore(memptr, owner)
                    mstore(add(memptr, 0x20), _operatorApprovals.slot)
                    let operatorApprovalInnerHash := keccak256(memptr, 0x40)
                    mstore(memptr, caller())
                    mstore(add(memptr, 0x20), operatorApprovalInnerHash)

                    if iszero(sload(keccak256(memptr, 0x40))) {
                        mstore(0x00, accessDeniedSelector)
                        revert(0x00, 0x04)
                    }
                }
            }

            // update _from _balances
            mstore(memptr, _from)
            mstore(add(memptr, 0x20), _balances.slot)
            let fromBalanceHash := keccak256(memptr, 0x40)
            sstore(fromBalanceHash, sub(sload(fromBalanceHash), 1))

            // update _to _balances
            mstore(memptr, _to)
            mstore(add(memptr, 0x20), _balances.slot)
            let toBalanceHash := keccak256(memptr, 0x40)
            sstore(toBalanceHash, add(sload(toBalanceHash), 1))

            // update _owners
            sstore(ownerHash, _to)

            // emit Transfer
            log4(0, 0, transferEventHash, _from, _to, _tokenId)
        }
    }
}
