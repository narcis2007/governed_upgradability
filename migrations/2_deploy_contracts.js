var MyContract_v0 = artifacts.require("./MyContract_v0.sol");
var MyContract_v1 = artifacts.require("./MyContract_v1.sol");
var QToken = artifacts.require("./QToken.sol");
var QExecutiveGovernance = artifacts.require("./QExecutiveGovernance.sol");

module.exports = async function (deployer) {

    await deployer.deploy(QToken).then(async () => {
        var token = await QToken.deployed();
        await token.initialize("Q", 123456789);
        return token;
    });
    var token = await QToken.deployed();
    console.log("token address:")
    console.log(token.address)
    await deployer.deploy(QExecutiveGovernance, token.address, token.address).then(async () => {
        var governanceInstance = await QExecutiveGovernance.deployed();
        console.log("governance contract address:");
        console.log(governanceInstance.address);
        await token.approve(governanceInstance.address, 123456789);
    }, (err) => {
        console.log(err)
    })
    //TODO: zos deploy contract proxy, v0 & associate implementation then deploy v1, test v0 through proxy ; deploy token & mint, deploy governance contract, approve transfer to governance contract
    //TODO: zos set the governance contract as the admin of the proxy, add new proposal(update to v1) into the governance contract, approve it and execute
    //TODO: check if the contract has been updated

};