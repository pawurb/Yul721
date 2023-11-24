// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {MockNFTNonHolder} from "../src/test/MockNFTNonHolder.sol";
import {MockNFTHolder} from "../src/test/MockNFTHolder.sol";
import {MockNFTBuggyHolder} from "../src/test/MockNFTBuggyHolder.sol";
// import "../src/lib/YulDeployer.sol";
import "../src/lib/BytecodeDeployer.sol";

uint256 constant TOKEN_ID = 0;
address constant user2 = address(1);
address constant user3 = address(2);
address constant zeroAddress = address(0);

interface Yul721 {
    function totalSupply() external returns (uint256);
    function maxSupply() external returns (uint256);
    function name() external returns (string memory);
    function symbol() external returns (string memory);
    function balanceOf(address) external returns (uint256);
    function mint() external;
    function owner() external returns (address);
    function ownerOf(uint256) external returns (address);
    function nextId() external returns (uint256);
    function safeTransferFrom(address, address, uint256) external;
    function safeTransferFrom(address, address, uint256, bytes calldata) external;
    function transferFrom(address, address, uint256) external;
    function approve(address, uint256) external;
    function getApproved(uint256) external returns (address);
    function isApprovedForAll(address, address) external returns (bool);
    function setApprovalForAll(address, bool) external;
    function supportsInterface(bytes4) external returns (bool);

    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721InvalidReceiver(address receiver);
    error ERC721AccessDenied();
    error ERC721InvalidAddress(address receiver);
    error ERC721MintLimit();
    error ERC721MaxSupplyLimit();
}

contract BaseTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // YulDeployer yulDeployer = new YulDeployer();
    BytecodeDeployer bytecodeDeployer = new BytecodeDeployer();
    Yul721 yul;
    address me;
    address nftNonHolder;
    address nftHolder;
    address nftBuggyHolder;

    function setUp() public virtual {
        yul = Yul721(bytecodeDeployer.deployContract("Yul721"));
        me = address(this);
        nftNonHolder = address(new MockNFTNonHolder());
        nftHolder = address(new MockNFTHolder());
        nftBuggyHolder = address(new MockNFTBuggyHolder());
    }
}

contract AttributesTest is BaseTest {
    // can be deployed and has correct attributes
    function test_attributes() public {
        assertEq(yul.symbol(), "YUL");
        assertEq(yul.name(), "Yul 721");
        assertEq(yul.maxSupply(), 1024);
    }
}

contract MintTest is BaseTest {
    // can only be executed twice by each address
    function test_maxMintLimit() public {
        yul.mint();
        yul.mint();
        vm.expectRevert(Yul721.ERC721MintLimit.selector);
        yul.mint();
    }

    // mints an NFT token to the target account
    function test_mintTarget() public {
        yul.mint();
        assertEq(yul.ownerOf(TOKEN_ID), me);
        yul.mint();
        assertEq(yul.balanceOf(me), 2);
    }

    // increments totalSupply and nextId
    function test_incrementCounters() public {
        uint256 nextIdBefore = yul.nextId();
        assertEq(nextIdBefore, 0);

        uint256 totalSupplyBefore = yul.totalSupply();
        assertEq(totalSupplyBefore, 0);

        yul.mint();

        uint256 nextIdAfter = yul.nextId();
        assertEq(nextIdAfter, 1);

        uint256 totalSupplyAfter = yul.totalSupply();
        assertEq(totalSupplyAfter, 1);
    }

    // has working maxSupply limit
    function test_maxSupply() public {
        for (uint256 i = 0; i < 1024; i++) {
            vm.prank(address(uint160(i)));
            yul.mint();
        }

        vm.expectRevert(Yul721.ERC721MaxSupplyLimit.selector);
        yul.mint();
    }

    // emits a correct event
    function test_emitEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(zeroAddress, me, TOKEN_ID);
        yul.mint();
    }
}

contract BalanceOfTest is BaseTest {
    // returns correct balances
    function test_balanceOf() public {
        assertEq(yul.balanceOf(user2), 0);
        vm.startPrank(user2);
        yul.mint();
        yul.mint();
        assertEq(yul.balanceOf(user2), 2);
    }

    // balanceOf the zero address
    function test_balanceOfZero() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidAddress.selector, zeroAddress));
        yul.balanceOf(zeroAddress);
    }
}

contract TransferFromTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
    }

    // changes owner of a correct NFT token
    function test_changesOwner() public {
        address ownerBefore = yul.ownerOf(TOKEN_ID);
        assertEq(ownerBefore, me);

        uint256 balanceBefore = yul.balanceOf(me);
        assertEq(balanceBefore, 1);

        yul.transferFrom(me, user2, TOKEN_ID);

        address ownerAfter = yul.ownerOf(TOKEN_ID);
        assertEq(ownerAfter, user2);

        uint256 balanceAfter = yul.balanceOf(me);
        assertEq(balanceAfter, 0);

        uint256 otherBalanceAfter = yul.balanceOf(user2);
        assertEq(otherBalanceAfter, 1);
    }

    // does not allow transferring token that an address does not own
    function test_transferringTokensNotYourOwn() public {
        vm.prank(user2);
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        yul.transferFrom(me, user2, TOKEN_ID);
    }

    // emits a correct Transfer event
    function test_emitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(me, user2, TOKEN_ID);
        yul.transferFrom(me, user2, TOKEN_ID);
    }

    // 'transferFrom(address,address,uint256)' token to the zero address
    function test_transferFromToZero() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, zeroAddress));
        yul.transferFrom(me, zeroAddress, TOKEN_ID);
    }
}

contract SafeTransferFromTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
        yul.mint();
    }

    // changes owner of a correct NFT token
    function test_changesOwner() public {
        address ownerBefore = yul.ownerOf(TOKEN_ID);
        assertEq(ownerBefore, me);

        uint256 balanceBefore = yul.balanceOf(me);
        assertEq(balanceBefore, 2);

        yul.safeTransferFrom(me, user2, TOKEN_ID);

        address ownerAfter = yul.ownerOf(TOKEN_ID);
        assertEq(ownerAfter, user2);

        uint256 balanceAfter = yul.balanceOf(me);
        assertEq(balanceAfter, 1);
    }

    // does not allow transferring token that an address does not own
    function test_transferringTokensNotYourOwn() public {
        vm.prank(user2);
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        yul.safeTransferFrom(me, user2, TOKEN_ID);
    }

    // emits a correct Transfer event
    function test_emitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(me, user2, TOKEN_ID);
        yul.safeTransferFrom(me, user2, TOKEN_ID);
    }

    // will not transfer NFT to contract which does not implement 'onERC721Received' callback
    function test_transferToNFTNonHolder() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, nftNonHolder));

        yul.safeTransferFrom(me, nftNonHolder, TOKEN_ID);
    }

    // it transfers NFT to contract which implements a correct 'onERC721Received' callback
    function test_transferToNFTHolder() public {
        yul.safeTransferFrom(me, nftHolder, TOKEN_ID);
        assertEq(yul.ownerOf(TOKEN_ID), nftHolder);
    }

    // will not transfer NFT to contract which implements incorrect 'onERC721Received' callback
    function test_transferToNFTBuggyHolder() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, nftBuggyHolder));

        yul.safeTransferFrom(me, nftBuggyHolder, TOKEN_ID);
    }

    // 'safeTransferFrom(address,address,uint256)' token to the zero address
    function test_transferFromToZero() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, zeroAddress));
        yul.safeTransferFrom(me, zeroAddress, TOKEN_ID);
    }
}

contract SafeTransferFromBytesTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
        yul.mint();
    }

    // changes owner of a correct NFT token
    function test_changesOwner() public {
        address ownerBefore = yul.ownerOf(TOKEN_ID);
        assertEq(ownerBefore, me);

        uint256 balanceBefore = yul.balanceOf(me);
        assertEq(balanceBefore, 2);

        yul.safeTransferFrom(me, user2, TOKEN_ID, "");

        address ownerAfter = yul.ownerOf(TOKEN_ID);
        assertEq(ownerAfter, user2);

        uint256 balanceAfter = yul.balanceOf(me);
        assertEq(balanceAfter, 1);
    }

    // does not allow transferring token that an address does not own
    function test_transferringTokensNotYourOwn() public {
        vm.prank(user2);
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        yul.safeTransferFrom(me, user2, TOKEN_ID, "");
    }

    // emits a correct Transfer event
    function test_emitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(me, user2, TOKEN_ID);
        yul.safeTransferFrom(me, user2, TOKEN_ID, "");
    }

    // will not transfer NFT to contract which does not implement 'onERC721Received' callback
    function test_transferToNFTNonHolder() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, nftNonHolder));

        yul.safeTransferFrom(me, nftNonHolder, TOKEN_ID, "");
    }

    // it transfers NFT to contract which implements a correct 'onERC721Received' callback
    function test_transferToNFTHolder() public {
        yul.safeTransferFrom(me, nftHolder, TOKEN_ID, "");
        assertEq(yul.ownerOf(TOKEN_ID), nftHolder);
    }

    // will not transfer NFT to contract which implements incorrect 'onERC721Received' callback
    function test_transferToNFTBuggyHolder() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, nftBuggyHolder));

        yul.safeTransferFrom(me, nftBuggyHolder, TOKEN_ID, "");
    }

    // 'safeTransferFrom(address,address,uint256,bytes)' token to the zero address
    function test_transferFromToZero() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, zeroAddress));
        yul.safeTransferFrom(me, zeroAddress, TOKEN_ID, "");
    }
}

contract ApproveTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
        yul.mint();
    }

    // emits a correct event
    function test_emitEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(me, user2, TOKEN_ID);
        yul.approve(user2, TOKEN_ID);
    }

    // grants other account permission to transfer only a target token for 'transferFrom(address,address,uint256)'
    function test_approveTransferFrom() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.transferFrom(me, user2, TOKEN_ID);

        yul.approve(user2, TOKEN_ID);

        vm.prank(user2);
        yul.transferFrom(me, user2, TOKEN_ID);

        assertEq(yul.ownerOf(TOKEN_ID), user2);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.transferFrom(me, user2, TOKEN_ID + 1);
    }

    // grants other account permission to transfer only a target token for 'safeTransferFrom(address,address,uint256)'
    function test_approveSafeTransferFrom() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID);

        yul.approve(user2, TOKEN_ID);

        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID);

        assertEq(yul.ownerOf(TOKEN_ID), user2);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID + 1);
    }

    // grants other account permission to transfer only a target token for 'safeTransferFrom(address,address,uint256,bytes)'
    function test_approveSafeTransferFromBytes() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID, "");

        yul.approve(user2, TOKEN_ID);

        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID, "");

        assertEq(yul.ownerOf(TOKEN_ID), user2);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID + 1, "");
    }

    // can be called only be an account owning a target token
    function test_approveOnlyByOwner() public {
        yul.approve(user2, TOKEN_ID);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.approve(user3, TOKEN_ID);
    }
}

contract GetApprovedTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
    }

    // throws an error for non-existent token
    function test_nonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721NonexistentToken.selector, TOKEN_ID + 1));
        yul.getApproved(TOKEN_ID + 1);
    }

    // returns address approved as a target token operator
    function test_returnsAddress() public {
        yul.approve(user2, TOKEN_ID);
        assertEq(yul.getApproved(TOKEN_ID), user2);
    }
}

contract IsApprovedForAllTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
    }

    // returns address bool indicating if target account is approved for all tokens management as a target token operator
    function test_returnsBool() public {
        bool beforeApproval = yul.isApprovedForAll(me, user2);
        assertFalse(beforeApproval);

        yul.setApprovalForAll(user2, true);

        bool afterApproval = yul.isApprovedForAll(me, user2);
        assertTrue(afterApproval);
    }
}

contract SetApprovalForAllTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
        yul.mint();
    }

    // emits a correct event
    function test_emitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(me, user2, true);
        yul.setApprovalForAll(user2, true);

        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(me, user2, false);
        yul.setApprovalForAll(user2, false);
    }

    // grants target operator a permission to transferFrom(address,address,uint256) all the tokens and can be reverted
    function test_permissionForTransferFrom() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.transferFrom(me, user2, TOKEN_ID);

        yul.setApprovalForAll(user2, true);

        yul.transferFrom(me, user2, TOKEN_ID);
        assertEq(yul.balanceOf(user2), 1);

        yul.setApprovalForAll(user2, false);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.transferFrom(me, user2, TOKEN_ID + 1);
    }

    // grants target operator a permission to safeTransferFrom(address,address,uint256) all the tokens and can be reverted
    function test_permissionForSafeTransferFrom() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID);

        yul.setApprovalForAll(user2, true);

        yul.safeTransferFrom(me, user2, TOKEN_ID);
        assertEq(yul.balanceOf(user2), 1);

        yul.setApprovalForAll(user2, false);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID + 1);
    }

    // grants target operator a permission to safeTransferFrom(address,address,uint256,bytes) all the tokens and can be reverted
    function test_permissionForSafeTransferFromBytes() public {
        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID, "");

        yul.setApprovalForAll(user2, true);

        yul.safeTransferFrom(me, user2, TOKEN_ID, "");
        assertEq(yul.balanceOf(user2), 1);

        yul.setApprovalForAll(user2, false);

        vm.expectRevert(Yul721.ERC721AccessDenied.selector);
        vm.prank(user2);
        yul.safeTransferFrom(me, user2, TOKEN_ID + 1, "");
    }
}

contract SupportsInterfaceTest is BaseTest {
    // returns true for supported interfaces
    function test_supportedInterfaces() public {
        assertTrue(yul.supportsInterface(0x01ffc9a7));
        assertTrue(yul.supportsInterface(0x80ac58cd));
    }

    // returns false for not supported interfaces
    function test_notSupportedInterfaces() public {
        assertFalse(yul.supportsInterface(0x12121212));
    }
}

contract EdgeCasesTest is BaseTest {
    function setUp() public override {
        super.setUp();
        yul.mint();
        yul.mint();
    }

    // 'transferFrom(address,address,uint256)' token to the zero address
    function test_transferFromToZero() public {
        vm.expectRevert(abi.encodeWithSelector(Yul721.ERC721InvalidReceiver.selector, zeroAddress));
        yul.safeTransferFrom(me, zeroAddress, TOKEN_ID);
    }
}
