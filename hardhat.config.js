/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    sepolia: {
      url: process.env.SEPOLIA_PROVIDER,
      accounts: [process.env.PRIVATE_KEY],
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 100,
            details: {
              constantOptimizer: false,
              deduplicate: true,
              yul: true,
            },
          },
        },
      },
    ],
  },
};
