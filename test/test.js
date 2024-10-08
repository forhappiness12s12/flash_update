const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniswapV3 Flash Loan Contract", function () {
  let owner, receiver, user, flashContract, FlashParams;

  before(async () => {
    [owner, user, receiver] = await ethers.getSigners();

    // Deploy the flash loan contract
    const FlashContract = await ethers.getContractFactory("myFlash");
    flashContract = await FlashContract.deploy(owner.address);

    // Log contract owner
    const contractOwner = await flashContract.getOwner();
    console.log("Contract Owner:", contractOwner);
    console.log("Signer:", owner.address);

    // Initialize FlashParams (amount will be updated in the loop)
    FlashParams = {
      token: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
      pairtoken: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
      amount: ethers.utils.parseEther("0.1"), // starting value
      usePath: 0,
      path1: 0,
      path2: 4
    };
  });

  it("Should execute flash loan and profit for different amounts", async function () {
    // Loop FlashParams.amount from 0.1 to 2 ether
    // for (let i = 0.1; i <= 2; i += 0.1) {
      // FlashParams.amount = ethers.utils.parseEther(i.toString());
      // console.log("Testing with amount:", FlashParams.amount.toString());

      await flashContract.connect(owner).callFlash(FlashParams);
    // }
  });
});
