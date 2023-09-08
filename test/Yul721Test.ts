import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect, assert } from "chai";
import { ethers } from "hardhat";
import {
  BN,
  constants,
  expectEvent,
  expectRevert,
} from "@openzeppelin/test-helpers";

const advanceByDays = async (days) => {
  await time.increase(days * 86400);
};

const TOKEN_ID = 0;

describe("Yul721 NFT", () => {
  let yul;
  let admin;
  let user2;
  let user3;
  let nftHolder;
  let nftBuggyHolder;
  let nftNonHolder;

  const setup = async (opts) => {
    admin = (await ethers.getSigners())[0];
    user2 = (await ethers.getSigners())[1];
    user3 = (await ethers.getSigners())[2];
    const Yul721 = await ethers.getContractFactory("Yul721");
    yul = await Yul721.deploy(admin.address);
    const MockNFTHolder = await ethers.getContractFactory("MockNFTHolder");
    const MockNFTBuggyHolder = await ethers.getContractFactory(
      "MockNFTBuggyHolder"
    );
    const MockNFTNonHolder = await ethers.getContractFactory(
      "MockNFTNonHolder"
    );
    nftHolder = await MockNFTHolder.deploy();
    nftBuggyHolder = await MockNFTBuggyHolder.deploy();
    nftNonHolder = await MockNFTNonHolder.deploy();
  };

  beforeEach(async () => {
    await setup({});
  });

  it("can be deployed and has correct attributes", async () => {
    assert.ok(yul.target);
    expect(await yul.name()).to.eq("Yul 721");
    expect(await yul.symbol()).to.eq("YUL");
    expect(await yul.admin()).to.eq(admin.address);
  });

  describe("'balanceOf'", async () => {
    it("returns correct balances", async () => {
      let balance1 = await yul.balanceOf(user2.address);
      expect(balance1).to.equal(0);

      await yul.mint(user2.address);
      let balance2 = await yul.balanceOf(user2.address);
      expect(balance2).to.equal(1);

      await yul.burn(TOKEN_ID);
      let balance3 = await yul.balanceOf(user2.address);
      expect(balance3).to.equal(0);
    });
  });

  describe("'transferFrom'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
    });

    it("changes owner of a correct NFT token", async () => {
      let ownerBefore = await yul.ownerOf(TOKEN_ID);
      expect(ownerBefore).to.equal(user2.address);

      await expect(
        await yul
          .connect(user2)
          .transferFrom(user2.address, user3.address, TOKEN_ID)
      ).to.changeTokenBalances(yul, [user2.address, user3.address], [-1, 1]);

      let ownerAfter = await yul.ownerOf(TOKEN_ID);
      expect(ownerAfter).to.equal(user3.address);
    });

    it("emits a correct Transfer event", async () => {
      await expect(
        yul.connect(user2).transferFrom(user2.address, user3.address, TOKEN_ID)
      )
        .to.emit(yul, "Transfer")
        .withArgs(user2.address, user3.address, TOKEN_ID);
    });

    it("does not allow transferring token that an address does not own", async () => {
      await expectRevert(
        yul.connect(user3).transferFrom(user2.address, user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );
    });
  });

  describe("'safeTransferFrom(address,address,uint256)'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      await yul.mint(user2.address);
    });

    it("changes owner of a correct NFT token", async () => {
      let ownerBefore = await yul.ownerOf(TOKEN_ID);
      expect(ownerBefore).to.equal(user2.address);

      await expect(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID
          )
      ).to.changeTokenBalances(yul, [user2.address, user3.address], [-1, 1]);

      let ownerAfter = await yul.ownerOf(TOKEN_ID);
      expect(ownerAfter).to.equal(user3.address);
    });

    it("emits a correct Transfer event", async () => {
      await expect(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID
          )
      )
        .to.emit(yul, "Transfer")
        .withArgs(user2.address, user3.address, TOKEN_ID);
    });

    it("does not allow transferring token that an address does not own", async () => {
      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID
          ),
        "ERC721AccessDenied"
      );
    });

    it("will not transfer NFT to contract which does not implement a correct 'onERC721Received' callback", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            nftNonHolder.target,
            TOKEN_ID
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("transfers NFT to contract which implements 'onERC721Received' callback", async () => {
      await yul
        .connect(user2)
        ["safeTransferFrom(address,address,uint256)"](
          user2.address,
          nftHolder.target,
          TOKEN_ID + 1
        );
      let newOwner = await yul.ownerOf(TOKEN_ID + 1);
      expect(newOwner).to.equal(nftHolder.target);
    });

    it("will not transfer NFT to contract which implements incorrect 'onERC721Received' callback", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            nftBuggyHolder.target,
            TOKEN_ID
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("with calldata it transfers NFT to contract which implements 'onERC721Received' callback", async () => {
      await yul
        .connect(user2)
        ["safeTransferFrom(address,address,uint256)"](
          user2.address,
          nftHolder.target,
          TOKEN_ID + 1
        );

      let newOwner = await yul.ownerOf(TOKEN_ID + 1);
      expect(newOwner).to.equal(nftHolder.target);
    });
  });

  describe("'safeTransferFrom(address,address,uint256,bytes)'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      await yul.mint(user2.address);
    });

    it("changes owner of a correct NFT token", async () => {
      let ownerBefore = await yul.ownerOf(TOKEN_ID);
      expect(ownerBefore).to.equal(user2.address);

      await expect(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID,
            "0x12"
          )
      ).to.changeTokenBalances(yul, [user2.address, user3.address], [-1, 1]);

      let ownerAfter = await yul.ownerOf(TOKEN_ID);
      expect(ownerAfter).to.equal(user3.address);
    });

    it("emits a correct Transfer event", async () => {
      await expect(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID,
            "0x12"
          )
      )
        .to.emit(yul, "Transfer")
        .withArgs(user2.address, user3.address, TOKEN_ID);
    });

    it("does not allow transferring token that an address does not own", async () => {
      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721AccessDenied"
      );
    });

    it("will not transfer NFT to contract which does not implement 'onERC721Received' callback", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            nftNonHolder.target,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("transfers NFT to contract which implements a correct 'onERC721Received' callback", async () => {
      await yul
        .connect(user2)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          user2.address,
          nftHolder.target,
          TOKEN_ID + 1,
          "0x12"
        );
      let newOwner = await yul.ownerOf(TOKEN_ID + 1);
      expect(newOwner).to.equal(nftHolder.target);
    });

    it("will not transfer NFT to contract which implements incorrect 'onERC721Received' callback", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            nftBuggyHolder.target,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("it transfers NFT to contract which implements 'onERC721Received' callback (for debug)", async () => {
      try {
        await yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            nftHolder.target,
            TOKEN_ID + 1,
            "0x12"
          );
      } catch (e) {
        let r = new RegExp(/(0x).+/, "i");

        // console.log(e.message.match(r)[0].split('').lastIndexOf('8'))
        console.log(e.message);
      }
      let newOwner = await yul.ownerOf(TOKEN_ID + 1);
      expect(newOwner).to.equal(nftHolder.target);
    });

    it("it transfers NFT to contract which implements a correct 'onERC721Received' callback", async () => {
      await yul
        .connect(user2)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          user2.address,
          nftHolder.target,
          TOKEN_ID + 1,
          "0x12"
        );

      let newOwner = await yul.ownerOf(TOKEN_ID + 1);
      expect(newOwner).to.equal(nftHolder.target);
    });
  });

  describe("'mint'", async () => {
    it("can only be executed by the admin", async () => {
      await expectRevert(
        yul.connect(user2).mint(user2.address),
        "ERC721AccessDenied"
      );

      await yul.mint(user2.address);
    });

    it("mints an NFT token to the target account", async () => {
      let nextIdBefore = await yul.nextId();
      expect(nextIdBefore).to.equal(0);
      await expect(yul.mint(user2.address)).to.changeTokenBalances(
        yul,
        [user2.address],
        [1]
      );

      let nextIdAfter = await yul.nextId();
      expect(nextIdAfter).to.equal(1);

      expect(await yul.ownerOf(TOKEN_ID)).to.eq(user2.address);

      await expect(yul.mint(user2.address)).to.changeTokenBalances(
        yul,
        [user2.address],
        [1]
      );

      expect(await yul.ownerOf(TOKEN_ID + 1)).to.eq(user2.address);
    });

    it("increments totalSupply and nextId", async () => {
      let supplyBefore = await yul.totalSupply();
      expect(supplyBefore).to.equal(0);
      let nextIdBefore = await yul.nextId();
      expect(nextIdBefore).to.equal(0);

      await yul.mint(user2.address);

      let supplyAfter = await yul.totalSupply();
      expect(supplyAfter).to.equal(1);
      let nextIdAfter = await yul.nextId();
      expect(nextIdAfter).to.equal(1);
    });
  });

  describe("'approve'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      await yul.mint(user2.address);
    });

    it("emits a correct event", async () => {
      await expect(yul.connect(user2).approve(user3.address, TOKEN_ID))
        .to.emit(yul, "Approval")
        .withArgs(user2.address, user3.address, TOKEN_ID);
    });

    it("grants other account permission to transfer only a target token for 'transferFrom(address,address,uint256)'", async () => {
      await expectRevert(
        yul.connect(user3).transferFrom(user2.address, user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).approve(user3.address, TOKEN_ID);

      await yul
        .connect(user3)
        .transferFrom(user2.address, user3.address, TOKEN_ID);
      let newOwner = await yul.ownerOf(TOKEN_ID);
      expect(newOwner).to.equal(user3.address);

      await expectRevert(
        yul
          .connect(user3)
          .transferFrom(user2.address, user3.address, TOKEN_ID + 1),
        "ERC721AccessDenied"
      );
    });

    it("grants other account permission to transfer only a target token for 'safeTransferFrom(address,address,uint256)'", async () => {
      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID
          ),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).approve(user3.address, TOKEN_ID);

      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256)"](
          user2.address,
          user3.address,
          TOKEN_ID
        );
      let newOwner = await yul.ownerOf(TOKEN_ID);
      expect(newOwner).to.equal(user3.address);

      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID + 1
          ),
        "ERC721AccessDenied"
      );
    });

    it("grants other account permission to transfer only a target token for 'safeTransferFrom(address,address,uint256,bytes)'", async () => {
      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).approve(user3.address, TOKEN_ID);

      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          user2.address,
          user3.address,
          TOKEN_ID,
          "0x12"
        );
      let newOwner = await yul.ownerOf(TOKEN_ID);
      expect(newOwner).to.equal(user3.address);

      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID + 1,
            "0x12"
          ),
        "ERC721AccessDenied"
      );
    });

    it("can be called only be an account owning a target token", async () => {
      await expectRevert(
        yul.connect(user3).approve(user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );

      await expectRevert(
        yul.connect(admin).approve(user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );
    });
  });

  describe("'getApproved'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
    });

    it("throws an error for non-existent token", async () => {
      await expectRevert(
        yul.connect(user3).getApproved(TOKEN_ID + 1),
        "ERC721NonexistentToken(1)"
      );
    });

    it("returns address approved as a target token operator", async () => {
      await yul.connect(user2).approve(user3.address, TOKEN_ID);
      let operator = await yul.connect(user2).getApproved(TOKEN_ID);
      expect(operator).to.equal(user3.address);
    });
  });

  describe("'isApprovedForAll'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
    });

    it("returns address bool indicating if target account is approved for all tokens management as a target token operator", async () => {
      let before = await yul
        .connect(user3)
        .isApprovedForAll(user2.address, user3.address);
      expect(before).to.equal(false);

      await yul.connect(user2).setApprovalForAll(user3.address, true);

      let after = await yul
        .connect(user3)
        .isApprovedForAll(user2.address, user3.address);
      expect(after).to.equal(true);
    });
  });

  describe("'setApprovalForAll'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      await yul.mint(user2.address);
      await yul.mint(user2.address);
    });

    it("emits a correct event", async () => {
      await expect(yul.connect(user2).setApprovalForAll(user3.address, true))
        .to.emit(yul, "ApprovalForAll")
        .withArgs(user2.address, user3.address, true);

      await expect(yul.connect(user2).setApprovalForAll(user3.address, false))
        .to.emit(yul, "ApprovalForAll")
        .withArgs(user2.address, user3.address, false);
    });

    it("grants target operator a permission to transferFrom(address,address,uint256) all the tokens and can be reverted", async () => {
      await expectRevert(
        yul.connect(user3).transferFrom(user2.address, user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).setApprovalForAll(user3.address, true);

      await yul
        .connect(user3)
        .transferFrom(user2.address, user3.address, TOKEN_ID);
      await yul
        .connect(user3)
        .transferFrom(user2.address, user3.address, TOKEN_ID + 1);
      await yul.connect(user2).setApprovalForAll(user3.address, false);

      await expectRevert(
        yul
          .connect(user3)
          .transferFrom(user2.address, user3.address, TOKEN_ID + 2),
        "ERC721AccessDenied"
      );
    });

    it("grants target operator a permission to safeTransferFrom(address,address,uint256) all the tokens and can be reverted", async () => {
      await expectRevert(
        yul.connect(user3).transferFrom(user2.address, user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).setApprovalForAll(user3.address, true);

      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256)"](
          user2.address,
          user3.address,
          TOKEN_ID
        );
      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256)"](
          user2.address,
          user3.address,
          TOKEN_ID + 1
        );
      await yul.connect(user2).setApprovalForAll(user3.address, false);

      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            user3.address,
            TOKEN_ID + 2
          ),
        "ERC721AccessDenied"
      );
    });

    it("grants target operator a permission to safeTransferFrom(address,address,uint256,bytes) all the tokens and can be reverted", async () => {
      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721AccessDenied"
      );

      await yul.connect(user2).setApprovalForAll(user3.address, true);

      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          user2.address,
          user3.address,
          TOKEN_ID,
          "0x12"
        );
      await yul
        .connect(user3)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          user2.address,
          user3.address,
          TOKEN_ID + 1,
          "0x12"
        );
      await yul.connect(user2).setApprovalForAll(user3.address, false);

      await expectRevert(
        yul
          .connect(user3)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            user3.address,
            TOKEN_ID + 2,
            "0x12"
          ),
        "ERC721AccessDenied"
      );
    });
  });

  describe("'burn'", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      await yul.mint(user2.address);
    });

    it("can be called only by a contract admin", async () => {
      await expectRevert(
        yul.connect(user2).burn(TOKEN_ID),
        "ERC721AccessDenied"
      );
    });

    it("can be called only for existing token ID", async () => {
      await expectRevert(yul.burn(TOKEN_ID + 2), "ERC721NonexistentToken(2)");
    });

    it("destroys a target NFT and clears balances", async () => {
      let ownerBefore = await yul.ownerOf(TOKEN_ID);
      expect(ownerBefore).to.equal(user2.address);

      let balanceBefore = await yul.balanceOf(user2.address);
      expect(balanceBefore).to.equal(2);
      await yul.burn(TOKEN_ID);

      let ownerAfter = await yul.ownerOf(TOKEN_ID);
      expect(ownerAfter).to.equal(constants.ZERO_ADDRESS);

      let balanceAfter = await yul.balanceOf(user2.address);
      expect(balanceAfter).to.equal(1);
    });

    it("decrements totalSupply but not nextId", async () => {
      let supplyBefore = await yul.totalSupply();
      expect(supplyBefore).to.equal(2);
      let nextIdBefore = await yul.nextId();
      expect(nextIdBefore).to.equal(2);

      await yul.burn(TOKEN_ID);

      let supplyAfter = await yul.totalSupply();
      expect(supplyAfter).to.equal(1);
      let nextIdAfter = await yul.nextId();
      expect(nextIdAfter).to.equal(2);
    });
  });

  describe("edge cases", async () => {
    beforeEach(async () => {
      await yul.mint(user2.address);
      const MockERC721A = await ethers.getContractFactory("MockERC721A");
      await yul.mint(user2.address);
    });

    it("'mint' emits a correct event", async () => {
      await expect(yul.mint(user2.address))
        .to.emit(yul, "Transfer")
        .withArgs(constants.ZERO_ADDRESS, user2.address, TOKEN_ID + 2);
    });

    it("'burn' emits a correct event", async () => {
      await expect(yul.burn(TOKEN_ID))
        .to.emit(yul, "Transfer")
        .withArgs(user2.address, constants.ZERO_ADDRESS, TOKEN_ID);
    });

    it("'transferFrom(address,address,uint256)' token to the zero address", async () => {
      await expectRevert(
        yul
          .connect(user2)
          .transferFrom(user2.address, constants.ZERO_ADDRESS, TOKEN_ID),
        "ERC721InvalidReceiver"
      );
    });

    it("'safeTransferFrom(address,address,uint256)' token to the zero address", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256)"](
            user2.address,
            constants.ZERO_ADDRESS,
            TOKEN_ID
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("'safeTransferFrom(address,address,uint256,bytes)' token to the zero address", async () => {
      await expectRevert(
        yul
          .connect(user2)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            user2.address,
            constants.ZERO_ADDRESS,
            TOKEN_ID,
            "0x12"
          ),
        "ERC721InvalidReceiver"
      );
    });

    it("balanceOf the zero address", async () => {
      await expectRevert(
        yul.connect(user2).balanceOf(constants.ZERO_ADDRESS),
        "ERC721InvalidAddress"
      );
    });

    it("trying to approve not owned token", async () => {
      await expectRevert(
        yul.connect(user3).approve(user3.address, TOKEN_ID),
        "ERC721AccessDenied"
      );
    });
  });
});
