const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniswapV3 Flash Loan Contract", function () {
  let owner, receiver, poolA, poolB, tokenA, tokenB, flashContract;
  let amountX = ethers.utils.parseUnits("50", 6); // 10 tokens
  let amountY = ethers.utils.parseUnits("50", 6); // 50,000 USDT (assuming tokenB is USDT)
  const poolAAddress="0x5969EFddE3cF5C0D9a88aE51E47d721096A97203";
  const poolBAddress="0x53C6ca2597711Ca7a73b6921fAf4031EeDf71339";
  const tokenBAddress="0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9";
  const tokenAAddress="0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f";
  before(async () => {
    [owner, receiver] = await ethers.getSigners();
    // Deploy the flash loan contract
    const FlashContract = await ethers.getContractFactory("uniswapv3_flash");
    flashContract = await FlashContract.deploy(owner.address);
    // Assign tokens and pools
    tokenA = await ethers.getContractAt("IERC20", tokenAAddress);
    tokenB = await ethers.getContractAt("IERC20", tokenBAddress);
    poolA = await ethers.getContractAt("IUniswapV3Pool", poolAAddress);
    poolB = await ethers.getContractAt("IUniswapV3Pool", poolBAddress);

    // Distribute some tokens to the contract and the owner for testing
    });

  it("Should execute flash loan and profit", async function () {
    // Ensure initial balances
    const initialBalanceA = await tokenA.balanceOf(flashContract.address);
    const initialBalanceB = await tokenB.balanceOf(flashContract.address);
    
    console.log("Initial balance of TokenA in flash loan contract:", ethers.utils.formatUnits(initialBalanceA, 6));
    console.log("Initial balance of TokenB in flash loan contract:", ethers.utils.formatUnits(initialBalanceB, 6));
    
    // Approve the contract to use tokens for flash loan
    await tokenB.connect(owner).approve(flashContract.address,amountX+amountY);
    // await tokenB.connect(owner).approve(flashContract.address, amountY);
    // console.log("poolaAddress:",poolA.address)c;
    // Execute the flash loan
    await flashContract.connect(owner).execute_flash(
      amountX,
      amountY,
      poolA.address,
      poolB.address,
      tokenA.address,
      tokenB.address,
      receiver.address
    );

    // Check final balances after the flash loan
    const finalBalanceA = await tokenA.balanceOf(flashContract.address);
    const finalBalanceB = await tokenB.balanceOf(flashContract.address);
    const receiverBalance = await tokenA.balanceOf(receiver.address);

    console.log("Final balance of TokenA in flash loan contract:", ethers.utils.formatUnits(finalBalanceA, 18));
    console.log("Final balance of TokenB in flash loan contract:", ethers.utils.formatUnits(finalBalanceB, 6));
    console.log("Receiver's balance of TokenA after flash loan:", ethers.utils.formatUnits(receiverBalance, 18));

    // Expect some profit in tokenA
    expect(finalBalanceA).to.be.gt(initialBalanceA);
  });
});
