import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();
import "@nomiclabs/hardhat-ethers";
import '@typechain/hardhat'
import "solidity-coverage"
import "hardhat-gas-reporter"
import "@nomicfoundation/hardhat-chai-matchers"
import "@openzeppelin/hardhat-upgrades";

import "./tasks/accounts";
import "./tasks/balance";
import "./tasks/block-number";

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const COINMARKETCAP_KEY = process.env.COINMARKETCAP_KEY;
const NODE_PROVIDER = process.env.NODE_PROVIDER || "";
const INFURA_API_KEY = process.env.INFURA_KEY || "";

module.exports = {

  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // defaultNetwork: "mainnet",
   defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        // url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
        url: NODE_PROVIDER,
        blockNumber: 16255651,
        // blockNumber: 16918517,
        // blockNumber: 16774421,
        accounts: [`0x${PRIVATE_KEY}`],
        gas: 2100000,
        gasPrice: 8000000000
      },
      allowUnlimitedContractSize: true,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: [`0x${PRIVATE_KEY}`],
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    mainnet: {
      url: NODE_PROVIDER,
      accounts: [`0x${PRIVATE_KEY}`],
      // gasPrice: 100000000000
      allowUnlimitedContractSize: true,
    },
  },
  mocha: {
    timeout: 200000
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    coinmarketcap: COINMARKETCAP_KEY
  }
};