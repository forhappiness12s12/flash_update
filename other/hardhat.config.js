// require("@nomicfoundation/hardhat-toolbox");
// require("@nomicfoundation/hardhat-ethers");
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify")

/** @type import('hardhat/config').HardhatUserConfig */

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
      // forking:{
      //   url:,
      //   gas:,
      //   gasprice:

      // },
      // allowUnlimitedContractSize:true,
    },
    
  }
};

