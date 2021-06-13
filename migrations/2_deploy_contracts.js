const startFiToken = artifacts.require("StartFiToken");
const StartfiNFT = artifacts.require("StartfiNFT");
const StartfiMarketPlace = artifacts.require("StartfiMarketPlace");
const StartfiRoyaltyNFT = artifacts.require("StartfiRoyaltyNFT")
module.exports = async (deployer, network, accounts
    // accounts: string[]
) => {
    console.log(network);
    if (network === "ropsten-fork") {
        let tokenName = "StartFiToken", symbol = "STFI", initialSupply, owner = accounts[0];
        await deployer.deploy(startFiToken, tokenName, symbol, owner);
        await deployer.deploy(StartfiNFT, tokenName, symbol, "http://ipfs.io");
        console.log(`StartfiToken deployed at ${startFiToken.address} in network: ${network}.`);
        await deployer.deploy(StartfiMarketPlace, "Test ERC721", StartfiNFT.address, startFiToken.address);
        console.log(`StartfiMarketPlace deployed at ${StartfiMarketPlace.address} in network: ${network}.`);
        await deployer.deploy(StartfiRoyaltyNFT, tokenName, symbol, "http://ipfs.io")
    }

    if (network === "development") {
        await deployer.deploy(startFiToken, tokenName, symbol, owner);
        await deployer.deploy(StartfiNFT, tokenName, symbol, "http://ipfs.io");
        console.log(`StartfiToken deployed at ${startFiToken.address} in network: ${network}.`);
        await deployer.deploy(StartfiMarketPlace, "Test ERC721", StartfiNFT.address, startFiToken.address);
        console.log(`StartfiMarketPlace deployed at ${StartfiMarketPlace.address} in network: ${network}.`);
        await deployer.deploy(StartfiRoyaltyNFT, tokenName, symbol, "http://ipfs.io")
    }
    if (network === "bsctestnet") {
        // await deployer.deploy(
        //   NFTKEYMarketPlaceV1_1,
        //   "Life",
        //   "0x58BC78f17059Bd09561dB4D6b18eEBBfE1De555a", // Life
        //   "0xae13d989dac2f0debff460ac112a837c89baa7cd" // WBNB Testnet
        // );
        // const marketplaceV1 = await NFTKEYMarketPlaceV1_1.deployed();
        // console.log(
        //   `NFTKEYMarketPlaceV1_1 for Life deployed at ${marketplaceV1.address} in network: ${network}.`
        // );
    }
    if (network === "bsc") {
        // await deployer.deploy(NFTKEYMarketPlaceV1_1, "NeuralPepe", "0x3c78B3066868C636c584a13Ec0a15b82e1E9511d", // NeuralPepe
        // "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c" // WBNB
        // );
        // const marketplaceV1 = await NFTKEYMarketPlaceV1_1.deployed();
        // console.log(`NFTKEYMarketPlaceV1_1 for NeuralPepe deployed at ${marketplaceV1.address} in network: ${network}.`);
    }
    if (network === "ropsten") {
        // await deployer.deploy(
        //   NFTKEYMarketPlaceV1_1,
        //   "Life",
        //   "0x32d8021324af928F864C23b7912C8c3F11cC4Cdc", // Life Ropsten
        //   "0xc778417E063141139Fce010982780140Aa0cD5Ab" // WETH Ropsten
        // );
        // const marketplaceV1 = await NFTKEYMarketPlaceV1_1.deployed();
        // console.log(
        //   `NFTKEYMarketPlaceV1_1 for Life deployed at ${marketplaceV1.address} in network: ${network}.`
        // );
    }
    if (network === "main") {
        // await deployer.deploy(
        //   NFTKEYMarketPlaceV1_1,
        //   "Pixls",
        //   "0x082903f4e94c5e10A2B116a4284940a36AFAEd63", // Pixls
        //   "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" // WETH
        // );
        // const marketplaceV1 = await NFTKEYMarketPlaceV1_1.deployed();
        // console.log(
        //   `NFTKEYMarketPlaceV1_1 for Pixls deployed at ${marketplaceV1.address} in network: ${network}.`
        // );
    }
};
