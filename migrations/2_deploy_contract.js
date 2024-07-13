let Verifier = artifacts.require("Verifier");
let Test = artifacts.require("Test");

module.exports = function(deployer) {
    deployer.deploy(Test, Verifier.address);
};