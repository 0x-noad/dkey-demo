module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8080,
      network_id: "*"
    },
    loc_dkey_dkey: {
      network_id: "*",
      port: 8080,
      host: "127.0.0.1"
    }
  },
  mocha: {},
  compilers: {
    solc: {
      version: "0.7.0"
    }
  }
};
