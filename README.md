# Yul721 [![GH Actions](https://github.com/pawurb/Yul721/actions/workflows/test.yml/badge.svg)](https://github.com/pawurb/Yul721/actions)

`Yul721` is an implementation of the ERC-721 standard for non-fungible tokens (NFTs) in the [Yul inline assembly language](https://docs.soliditylang.org/en/v0.8.21/yul.html).

I've created this project for learning purposes, and it has not been audited for security.

Unfortunately, Etherscan does not validate Smart Contracts written in pure Yul (like the [official ERC20 example](https://docs.soliditylang.org/en/v0.8.21/yul.html#complete-erc20-example)). That's why methods interface is declared in a Solidity syntax.

## API

Contract implements a complete [ERC721 standard](https://eips.ethereum.org/EIPS/eip-721) with the following API:

`name()` and `symbol()` functions return the name and symbol of the NFT.

`balanceOf(address _account)` returns the balance of NFTs owned by a specific address.

`ownerOf(uint256 _tokenId)` returns the owner of a specific token.

`mint()` allows the creation of a new token. There's a limit of two mints per unique address.

`approve(address _to, uint256 _tokenId)` allows an address to approve another address to transfer a specific token.

`getApproved(uint256 _tokenId)` returns the address approved to transfer a specific token.

`setApprovalForAll(address _operator, bool _approved)` allows an owner to approve or revoke the ability of an operator to manage all their tokens.

`isApprovedForAll(address _owner, address _operator)` checks if an operator is approved to manage all tokens for a specific owner.

`transferFrom(address _from, address _to, uint256 _tokenId)` allows the transfer of a specific token from one address to another.

`safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata)` and `safeTransferFrom(address _from, address _to, uint256 _tokenId)` provide safe token transfers, checking if the recipient is a contract and calling `onERC721Received` if needed.
