const fs = require('fs-extra')
const path = require('path')

const DIR = path.resolve(__dirname)
const HDWalletProvider = require('@truffle/hdwallet-provider')
const getMnemonic = () => fs.readFileSync(path.join(DIR, ".mnemonic")).toString().trim()

module.exports = {
  networks: {
    okexchain: {
      provider: () => new HDWalletProvider({
        mnemonic: getMnemonic(),
        providerOrUrl: "https://exchainrpc.okex.org"
      }),
      gasPrice: 1e9,
      network_id: 66,
      timeoutBlocks: 200,
      skipDryRun: true,
    },
  },
  compilers: {
    solc: {
      version: "0.8.4",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      }
    }
  },
}
