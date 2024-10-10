// scripts/upgrade.js
const { ethers, upgrades } = require("hardhat");

async function main() {
    // Address of the deployed proxy contract
    const proxyAddress = "0xYourProxyAddress"; // Replace with your proxy contract address

    // Get the contract factory for the new implementation
    const MyFlashV2 = await ethers.getContractFactory("myFlashV2");

    // Upgrade the existing proxy to the new implementation
    const upgradedProxy = await upgrades.upgradeProxy(proxyAddress, MyFlashV2);
    await upgradedProxy.deployed();

    console.log("Proxy upgraded to new implementation at:", upgradedProxy.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
