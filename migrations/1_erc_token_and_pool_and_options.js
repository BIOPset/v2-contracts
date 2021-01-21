const BinaryOptions = artifacts.require("BinaryOptions");
const BIOPToken = artifacts.require("BIOPToken");
//const BN = web3.utils.BN;
//fake price provider
const FakePriceProvider = artifacts.require("FakePriceProvider");

const RateCalc = artifacts.require("RateCalc");

const biopSettings = {
  name: "BIOP",
  symbol: "BIOP",
};

const boSettings = {
  name: "Pool Share",
  symbol: "pETH",
  owner: "0xC961AfDcA1c4A2A17eada10D2e89D052bEf74A85",
  priceProviderAddress: "0x9326BFA02ADD2366b30bacB125260Af641031331", //"0x9326BFA02ADD2366b30bacB125260Af641031331" //kovan<- ->mainnet // "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", //mainnet address
};

const FakePriceSettings = {
  price: 753520000000,
};

const testing = true;

module.exports = function (deployer) {
  if (testing) {
    deployer
      .deploy(FakePriceProvider, FakePriceSettings.price)
      .then((ppInstance) => {
        return deployer.deploy(RateCalc).then((rcInstance) => {
          console.log("deploy 1 complete");
          console.log(ppInstance.address);
          return deployer
            .deploy(BIOPToken, biopSettings.name, biopSettings.symbol)
            .then((biopInstance) => {
              console.log("deploy 2 complete");
              console.log(biopInstance.address);
              return deployer
                .deploy(
                  BinaryOptions,
                  boSettings.name,
                  boSettings.symbol,
                  ppInstance.address,
                  biopInstance.address,
                  rcInstance.address
                )
                .then(async (boInstance) => {
                  return await biopInstance.setupBinaryOptions(
                    boInstance.address
                  );
                });
            });
        });
      })
      .catch((e) => {
        console.log("caught");
        console.log(e);
      });
  } else {
    deployer
      .deploy(BIOPToken, biopSettings.name, biopSettings.symbol)
      .then((biopInstance) => {
        console.log("deploy 1 complete");
        console.log(biopInstance.address);
        return deployer.deploy(RateCalc).then((rcInstance) => {
          return deployer
            .deploy(
              BinaryOptions,
              boSettings.name,
              boSettings.symbol,
              boSettings.priceProviderAddress,
              biopInstance.address,
              rcInstance.address
            )
            .then(async (boInstance) => {
              return await biopInstance.setupBinaryOptions(boInstance.address);
            });
        });
      });
  }
};
