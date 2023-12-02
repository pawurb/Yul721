// SPDX-License-Identifier: MIT

object "Token" {
    code {
        sstore(0, 1024) // maxSupplySlot()

        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            switch selector()
            case 0x95d89b41 /* "symbol()" */ {
                mstore(0x00, 0x20)
                mstore(0x20, 0x3)
                mstore(0x40, 0x59554c0000000000000000000000000000000000000000000000000000000000) // "YUL"
                return(0x00, 0x60)
            }
            case 0x06fdde03 /* "name()" */ {
                mstore(0x00, 0x20)
                mstore(0x20, 0x7)
                mstore(0x40, 0x59756c2037323100000000000000000000000000000000000000000000000000) // "Yul 721"
                return(0x00, 0x60)
            }
            case 0xd5abeb01 /* "maxSupply()" */ {
                mstore(0x00, sload(maxSupplySlot()))
                return(0x0, 0x20)
            }
            case 0x01ffc9a7 /* "supportsInterface(bytes4)" */ {
              let _interfaceId := shr(224, calldataload(0x04))

              // erc165InterfaceId
              if eq(_interfaceId, 0x01ffc9a7) {
                  mstore(0x00, 1)
                  return(0x00, 0x20)
              }

              // erc721InterfaceId
              if eq(_interfaceId, 0x80ac58cd) {
                  mstore(0x00, 1)
                  return(0x00, 0x20)
              }

              mstore(0x00, 0)
              return(0x00, 0x20)
            }
            case 0x70a08231 /* "balanceOf(address)" */ {
                mstore(0x0, calldataload(0x04))
                let account := mload(0x0)

                if eq(account, 0) {
                    // `bytes4(keccak256("ERC721InvalidAddress(address)"))`
                    mstore(0x00, 0x46cce84100000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, account)
                    revert(0x00, 0x24)
                }

                mstore(0x20, balancesSlot())
                let balanceHash := keccak256(0x0, 0x40)

                let accountBalance := sload(balanceHash)
                mstore(0x00, accountBalance)
                return(0x00, 0x20)
            }
            case 0x1249c58b /* "mint()" */ {
                // check maxSupply
                if eq(sload(nextIdSlot()), sload(maxSupplySlot())) {
                    // `bytes4(keccak256("ERC721MaxSupplyLimit()"))`
                    mstore(0x00, 0x96c2a07600000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 0x04)
                }

                // check mintLimit
                mstore(0x0, caller())
                mstore(0x20, mintCountSlot())
                let mintCountHash := keccak256(0x0, 0x40)

                let mintCount := sload(mintCountHash)
                if gt(mintCount, 1) {
                    // `bytes4(keccak256("ERC721MintLimit()"))`
                    mstore(0x00, 0x3ca6616800000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 0x04)
                }

                // increment _mintCount
                sstore(mintCountHash, add(mintCount, 1))

                // increment nextId
                let nextIdVal := sload(nextIdSlot())
                sstore(nextIdSlot(), add(nextIdVal, 1))

                // update owners
                mstore(0x0, nextIdVal)
                mstore(0x20, ownersSlot())
                sstore(keccak256(0x0, 0x40), caller())

                incBalance(caller())

                emitTransfer(0, caller(), nextIdVal)
            }
            case 0x6352211e /* "ownerOf(uint256)" */ {
                mstore(0x0, calldataload(0x04))
                mstore(0x20, ownersSlot())
                mstore(0x00, sload(keccak256(0x0, 0x40)))
                return(0x00, 0x20)
            }
            case 0x61b8ce8c /* "nextId()" */ {
                mstore(0x0, sload(nextIdSlot()))
                return(0x0, 0x20)
            }

            case 0x18160ddd /* "totalSupply()" */ {
                mstore(0x0, sload(nextIdSlot()))
                return(0x0, 0x20)
            }
            case 0x23b872dd /* "transferFrom(address,address,uint256)" */ {
              let _from := decodeAsAddress(0)
              let _to := decodeAsAddress(1)
              let _tokenId := decodeAsUint(2)

              requireNonZeroAddress(_to)

              mstore(0x0, _tokenId)
              mstore(0x20, ownersSlot())
              let ownerHash := keccak256(0x0, 0x40)
              let owner := sload(ownerHash)

              checkTransferPermission(owner, _tokenId)

              decBalance(_from)
              incBalance(_to)

              // update _owners
              sstore(ownerHash, _to)

              emitTransfer(_from, _to, _tokenId)
            }
            case 0x42842e0e /* "safeTransferFrom(address,address,uint256)" */ {
              let _from := decodeAsAddress(0)
              let _to := decodeAsAddress(1)
              let _tokenId := decodeAsUint(2)

              requireNonZeroAddress(_to)

              // check onERC721Received
              mstore(0x00, onERC721ReceivedSelector())
              mstore(0x04, caller())
              mstore(0x24, calldataload(0x04))
              mstore(0x44, _tokenId)
              mstore(0x64, 0x80)

              if iszero(eq(extcodesize(_to), 0)) {
                  if iszero(call(gas(), _to, 0, 0, 0xa4, 0x00, 0x20)) {
                      mstore(0x00, invalidReceiverSelector())
                      mstore(0x04, _to)
                      revert(0x00, 0x24)
                  }

                  if iszero(eq(mload(0x00), onERC721ReceivedSelector())) {
                      mstore(0x00, invalidReceiverSelector())
                      mstore(0x04, _to)
                      revert(0x00, 0x24)
                  }
              }

              // check owner
              mstore(0x0, _tokenId)
              mstore(0x20, ownersSlot())
              let ownerHash := keccak256(0x0, 0x40)
              let owner := sload(ownerHash)

              checkTransferPermission(owner, _tokenId)

              decBalance(_from)
              incBalance(_to)

              // update _owners
              sstore(ownerHash, _to)

              emitTransfer(_from, _to, _tokenId)
            }
            case 0xb88d4fde /* "safeTransferFrom(address,address,uint256,bytes)" */ {
              let _from := decodeAsAddress(0)
              let _to := decodeAsAddress(1)
              let _tokenId := decodeAsUint(2)

              requireNonZeroAddress(_to)

              // check onERC721Received
              mstore(0x00, onERC721ReceivedSelector())
              mstore(0x04, caller())
              mstore(0x24, calldataload(0x04))
              mstore(0x44, _tokenId)
              calldatacopy(0x70, 0x70, 0x20)

              if iszero(eq(extcodesize(_to), 0)) {
                  if iszero(call(gas(), _to, 0, 0, 0xa4, 0x00, 0x20)) {
                      mstore(0x00, invalidReceiverSelector())
                      mstore(0x04, _to)
                      revert(0x00, 0x24)
                  }

                  if iszero(eq(mload(0x00), onERC721ReceivedSelector())) {
                      mstore(0x00, invalidReceiverSelector())
                      mstore(0x04, _to)
                      revert(0x00, 0x24)
                  }
              }

              mstore(0x0, _tokenId)
              mstore(0x20, ownersSlot())
              let ownerHash := keccak256(0x0, 0x40)
              let owner := sload(ownerHash)
              checkTransferPermission(owner, _tokenId)

              decBalance(_from)
              incBalance(_to)

              // update _owners
              sstore(ownerHash, _to)

              emitTransfer(_from, _to, _tokenId)
            }
            case 0x095ea7b3 /* "approve(address,uint256)" */ {
              let _to := decodeAsAddress(0)
              let _tokenId := decodeAsUint(1)
              mstore(0x0, _tokenId)
              mstore(0x20, ownersSlot())

              if iszero(eq(sload(keccak256(0x0, 0x40)), caller())) {
                  mstore(0x00, accessDeniedSelector())
                  revert(0x00, 0x04)
              }

              // update _tokenApprovals
              mstore(0x0, _tokenId)
              mstore(0x20, tokenApprovalsSlot())
              sstore(keccak256(0x0, 0x40), _to)

              // `keccak256("Approval(address,address,uint256)")`
              log4(0, 0, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, caller(), _to, _tokenId)
            }
            case 0x081812fc { /* getApproved(uint256) */
              let _tokenId := decodeAsUint(0)
              mstore(0x0, _tokenId)
              mstore(0x20, ownersSlot())
              let owner := sload(keccak256(0x0, 0x40))

              if eq(owner, 0) {
                  // `bytes4(keccak256("ERC721NonexistentToken(uint256)"))`
                  mstore(0x00, 0x7e27328900000000000000000000000000000000000000000000000000000000)
                  mstore(0x04, _tokenId)
                  revert(0x00, 0x24)
              }

              mstore(0x0, _tokenId)
              mstore(0x20, tokenApprovalsSlot())
              mstore(0x00, sload(keccak256(0x0, 0x40)))
              return(0x00, 0x20)
            }
            case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {
              let _owner := decodeAsAddress(0)
              let _operator := decodeAsAddress(1)
              mstore(0x0, _owner)
              mstore(0x20, operatorApprovalsSlot())
              let operatorApprovalInnerHash := keccak256(0x0, 0x40)
              mstore(0x0, _operator)
              mstore(0x20, operatorApprovalInnerHash)
              mstore(0x00, sload(keccak256(0x0, 0x40)))
              return(0x00, 0x20)
            }
            case 0xa22cb465 /* "setApprovalForAll(address,bool)" */ {
              let _operator := decodeAsAddress(0)
              let _approved := decodeAsUint(1)

              mstore(0x0, caller())
              mstore(0x20, operatorApprovalsSlot())
              let operatorApprovalInnerHash := keccak256(0x0, 0x40)
              mstore(0x0, _operator)
              mstore(0x20, operatorApprovalInnerHash)
              sstore(keccak256(0x0, 0x40), _approved)

              // emit ApprovalForAll
              mstore(0x00, _approved)
              // `keccak256("ApprovalForAll(address,address,bool)")`
              log3(0x00, 0x20, 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31, caller(), _operator)
            }
            default {
                mstore(0x00, 0x194)
                revert(0x0, 0x20)
            }

            /* Events */

            function emitTransfer(from, to, tokenId) {
              // `keccak256("Transfer(address,address,uint256)")`
              log4(0, 0, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, from, to, tokenId)
            }

            /* -------- storage slots ---------- */

            function maxSupplySlot() -> s { s := 0 }
            function ownerSlot() -> s { s := 1 }
            function nextIdSlot() -> s { s := 2 }
            function balancesSlot() -> s { s := 3 }
            function ownersSlot() -> s { s := 4 }
            function tokenApprovalsSlot() -> s { s := 5 }
            function mintCountSlot() -> s { s := 6 }
            function operatorApprovalsSlot() -> s { s := 7 }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }
            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }
            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }

            /* reused logic */

            function checkTransferPermission(owner, tokenId) {
              let isOwner := eq(owner, caller())
              if iszero(isOwner) {
                  // check _tokenApprovals
                  mstore(0x0, tokenId)
                  mstore(0x20, tokenApprovalsSlot())

                  if iszero(eq(caller(), sload(keccak256(0x0, 0x40)))) {
                      // check _operatorApprovals
                      mstore(0x0, owner)
                      mstore(0x20, operatorApprovalsSlot())
                      let operatorApprovalInnerHash := keccak256(0x0, 0x40)
                      mstore(0x0, caller())
                      mstore(0x20, operatorApprovalInnerHash)

                      if iszero(sload(keccak256(0x0, 0x40))) {
                          mstore(0x00, accessDeniedSelector())
                          revert(0x00, 0x04)
                      }
                  }
              }
            }

            function requireNonZeroAddress(to) {
              if eq(to, 0) {
                  mstore(0x00, invalidReceiverSelector())
                  mstore(0x04, to)
                  revert(0x00, 0x24)
              }
            }

            function incBalance(target) {
              mstore(0x0, target)
              mstore(0x20, balancesSlot())
              let targetBalanceHash := keccak256(0x0, 0x40)
              sstore(targetBalanceHash, add(sload(targetBalanceHash), 1))
            }

            function decBalance(target) {
              mstore(0x0, target)
              mstore(0x20, balancesSlot())
              let targetBalanceHash := keccak256(0x0, 0x40)
              sstore(targetBalanceHash, sub(sload(targetBalanceHash), 1))
            }

            /* signatures */

            function onERC721ReceivedSelector() -> s {
              // bytes4(keccak256("onERC721Received(address,address,uint256,bytes"))
              s := 0x150b7a0200000000000000000000000000000000000000000000000000000000
            }

            function accessDeniedSelector() -> s {
              // `bytes4(keccak256("ERC721AccessDenied()"))`
              s := 0x43df7c0200000000000000000000000000000000000000000000000000000000
            }

            function invalidReceiverSelector() -> s {
              // `bytes4(keccak256("ERC721InvalidReceiver(address)"))`
              s := 0x64a0ae9200000000000000000000000000000000000000000000000000000000
            }
        }
    }
}
