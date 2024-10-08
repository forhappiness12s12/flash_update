// require("@nomicfoundation/hardhat-toolbox");
// require("@nomicfoundation/hardhat-ethers");
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify")
require("dotenv")

/** @type import('hardhat/config').HardhatUserConfig */
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const PRIVATE_KEY1 = process.env.PRIVATE_KEY1;
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
      
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking:{
        url: 'https://arb-mainnet.g.alchemy.com/v2/7eOLHZwz5cGdg809c3NDqfFT1cBSUMYx',
        blockNumber: 261417880,
        accounts: [`0x${PRIVATE_KEY}`,`0x${PRIVATE_KEY1}`],
        // gas: 2100000,
        // gasPrice: 8000000000
      },
      allowUnlimitedContractSize:true,
    },
    
  }
};

