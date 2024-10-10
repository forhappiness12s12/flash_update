const { ethers, upgrades } = require("hardhat");

async function main() {
    const MyFlash = await ethers.getContractFactory("myFlash");
    const ownerAddress = "0xDc1D7DCd1D9Aa43310883725A7F12623ec15A353";
    // Get the deployer's account
    // const [deployer] = await ethers.getSigners();
    
    // // Log the deployer's address
    // console.log("Deploying contracts with the account:", deployer.address);

    const myFlashProxy = await upgrades.deployProxy(MyFlash, [ownerAddress], {
        initializer: "initialize",
    });

    await myFlashProxy.deployed();
    console.log("myFlash deployed to:", myFlashProxy.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });