const CryptoSOS = artifacts.require("CryptoSOS");
const MultySOS = artifacts.require("MultySOS");

module.exports = function(deployer) {
  deployer.deploy(CryptoSOS);
  deployer.deploy(MultySOS);
};
