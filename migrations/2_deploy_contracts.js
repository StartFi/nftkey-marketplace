const startFiToken = artifacts.require("StartFiToken");
const StartFiNFTPayment = artifacts.require("StartFiNFTPayment");
const StartfiNFT = artifacts.require("StartfiRoyaltyNFT");
const StartfiStakes = artifacts.require("StartfiStakes");
const StartfiMarketPlace = artifacts.require("StartFiMarketPlace");
module.exports = async (deployer, network,accounts
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
        await deployer.deploy(startFiToken,tokenName,symbol,owner);
         await deployer.deploy(StartfiNFT,tokenName,  symbol,   "http://ipfs.io");
         console.log(`StartfiToken deployed at ${startFiToken.address} in network: ${network}.`);
         const rNFT= await StartfiNFT.deployed();
          const isERC721 = await rNFT.supportsInterface("0x01ffc9a7");
         console.log(isERC721,'isERC721 ');
         const isERCRoyalty = await rNFT.supportsInterface("0x2a55205a");
         console.log(isERCRoyalty,'isERCRoyalty');
         
        await deployer.deploy(StartfiStakes, startFiToken.address);

        await deployer.deploy(StartFiNFTPayment, StartfiNFT.address, startFiToken.address);
        // add to minter role 
        await rNFT.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",StartFiNFTPayment.address)
        await deployer.deploy(StartfiMarketPlace, "Test ERC721",  startFiToken.address,StartfiStakes.address,);
         console.log(`StartfiMarketPlace deployed at ${StartfiMarketPlace.address} in network: ${network}.`);
            const staker = await StartfiStakes.deployed();
            await staker.setMarketplace(StartfiMarketPlace.address);
  
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
