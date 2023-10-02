// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        returns (bytes4);
}

contract MockNFTBuggyHolder is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual returns (bytes4) {
        return 0x64a0ae92; // invalid selector
    }
}
