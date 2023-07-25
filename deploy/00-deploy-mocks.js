/* Ginetai deploy mono se development chain */

const BASE_FEE = ethers.utils.parseEther("0.25") // 0.25 is this the premium in LINK? "250000000000000000". It cost 0.25 per request
const GAS_PRICE_LINK = 1e9 // link per gas, is this the gas lane? // 0.000000001 LINK per gas // calculated value based on the gas price of the chain

const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    //const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Loval network detected! Deploying mocks...")
        // deploy o mock vrfcoordinator...
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks Deployed!")
        log("----------------------------------------------------------")
        log("You are deploying to a local network, you'll need a local network running to interact")
        log(
            "Please run `yarn hardhat console --network localhost` to interact with the deployed smart contracts!",
        )
        log("----------------------------------------------------------")
    }
}
module.exports.tags = ["all", "mocks"]
