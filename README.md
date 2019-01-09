Instructions how to rest the governed upgradability:

Install ZeppelinOS 2.0: `npm install --global zos`

Install Ganache: https://truffleframework.com/ganache and make sure it runs on port 8545

`npm install`

`truffle migrate` - this should deploy the token, governance contract and initialize them, their addresses will be show in the console, save them somewhere because they will be needed later
 
in a new console`zos session --network development --from 0x2CF2A84F2f62128De32Fc055B75F4247Efa1a04E --expires 720000` the address is the second address from the ganache account list(or any address besides the first one can be there, there will be issues if it's the first one)

`zos push` - this will deploy the logic contracts and will create a file zos.dev-* with the details

`zos create MyContract_v0 --init initialize --args 64` - this will deploy the proxy for the logic contract deployed earlier and wil call the initialize function(the equivalent of the constructor in ZOS) with the value 64
 - this will print the address of the proxy, save it somewhere because it will be useful later on(or you can get it from the zos.dev-* file)
 
 now we should test the first version of the contract:
 
 `truffle console --network development`
 inside it:
 `let abi = require("./build/contracts/MyContract_v0.json").abi`
 `let contract = new web3.eth.Contract(abi, "{{your-proxy-address}}")` 
 `(await contract.methods.value()).call()` - should return 64
 `contract.methods.add(1).send({from:"0x6af8E70f2253E89c49f8AB19b728c958C0DEE76c"})` - the third address
 `(await contract.methods.value()).call()` - should return 66, the value has been added, this means we have a bug and we need to update the contract 
 we want the token holders to controll the upgrading process so we have to set the admin of the proxy contract to be the governance contract:
 outside of the truffle console in the project run
 `zos set-admin {{proxy-address}} {{governance-contract-address}} -y` - from this point only the governance contract can perform upgrades so let's add an upgrade proposal:
 
 go to https://abi.hashex.org 
 in the "Or enter your parameters manually" select your function and write "upgradeTo" in the first line and in the second select address and place the address of the second version of the logic contract, it can be found in zos.dev-*/contracts/MyContract_v1/address
 add a 0x in from of the string resulted and save it
 
 now it's time to add the proposal in the governance contract, in the truffle console write this:
 
 `let gov_abi = require("./build/contracts/QExecutiveGovernance.json").abi`
 `let gov_contract = new web3.eth.Contract(gov_abi, "{{governance_contract_address}}")`
 `gov_contract.methods.addProposal("{{proxy-contract-address}}",0,"{{0xencoded_data}}").send({from:"0xd1daEC4795bC607Cc009BAc60686e307E5051Ef8", gasLimit:2000000})`
 this will add an proposal to upgrade the implementation to MyContract_v1 where the bug isn't anymore
 now we should approve the proposal 
 `gov_contract.methods.voteProposal(0,11,true).send({from:"0xd1daEC4795bC607Cc009BAc60686e307E5051Ef8", gasLimit:2000000})` - vote yes with 11 tokens
 
 to check:
 `(await gov_contract.methods.getTokensForProposal(0,"0xd1daEC4795bC607Cc009BAc60686e307E5051Ef8")).call()` - should return 11
 `(await gov_contract.methods.getVerdictForProposal(0,"0xd1daEC4795bC607Cc009BAc60686e307E5051Ef8")).call()` - should return true
 now wait 5 minutes(that's the voting period for this POC)
 `(await gov_contract.methods.isTransactionProposalConfirmed(0)).call()` - when this returns true this means the proposal is approved and can be executed in order to update the implementation
 `gov_contract.methods.executeTransaction(0).send({from:"0xd1daEC4795bC607Cc009BAc60686e307E5051Ef8", gasLimit:2000000})` - this will perform the update
 now we can call the proxy again and the bug should not be there:
 
 `(await contract.methods.value()).call()` - should return 66, the last value
 `contract.methods.add(1).send({from:"0x6af8E70f2253E89c49f8AB19b728c958C0DEE76c"})` ress
 `(await contract.methods.value()).call()` - should return 67, works as intended now with no bugs
 
 The upgradability could be used to fix the state that was wrongly modified by buggy code too, for example if the DAO smart contracts used this mechanism, they could quickly update the logic contracts to get rid of the bug AND introduce some additional temporary code that would restore the funds back without the need for a hard fork
 
 And this is how you don't get unstoppabble bugs in your smart contracts :)
