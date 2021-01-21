var BinaryOptions = artifacts.require("BinaryOptions");
var BIOPToken = artifacts.require("BIOPToken");
var FakePriceProvider = artifacts.require("FakePriceProvider");

const toWei = (value) => web3.utils.toWei(value.toString(), "ether");
var basePrice = 753520000000;
var oneHour = 3600;
const send = (method, params = []) => 
  new Promise((resolve, reject) => 
    web3.currentProvider.send({id: 0, jsonrpc: "2.0", method, params}, (err, x) => {
      if(err) reject(err)
      else resolve(x)
    }))
const timeTravel = async(seconds) => {
  await send("evm_increaseTime", [seconds]);
  await send("evm_min");
}

const btcPriceOracle = "0x6135b13325bfC4B00278B4abC5e20bbce2D6580e";

contract("BinaryOptions", (accounts) => {
  it("exists", () => {
    return BinaryOptions.deployed().then(async function (instance) {
      assert.equal(
        typeof instance,
        "object",
        "Contract instance does not exist"
      );
    });
  });

  it("stake in BinaryOptions", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {
        await bo.stake({ from: accounts[2], value: toWei(9) });
        var balance = await bo.balanceOf(accounts[2]);

        assert.equal(
          balance.toString(),
          "9000000000000000000",
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("makes a call bet", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      var balance = await bo.balanceOf(accounts[2]);
      var defaultpp = await bo.defaultPriceProvider();
      console.log(`defaultpp ${defaultpp}`);
      await bo.bet(1, defaultpp, oneHour, {from: accounts[2], value: toWei(1)});
      assert.equal(
        balance.toString(),
        "9000000000000000000",
        "user balance after deposit is zero"
      );
    });
  }); 
  it("makes a put bet", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      var balance = await bo.balanceOf(accounts[2]);
      var defaultpp = await bo.defaultPriceProvider();
      await bo.bet(0,defaultpp,oneHour, {from: accounts[2], value: toWei(1)});
      assert.equal(
        balance.toString(),
        "9000000000000000000",
        "user balance after deposit is zero"
      );
    });
  }); 
  it("exercise an call option", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {
        var ethB1 = await web3.eth.getBalance(accounts[2]);
        //var balance = await bo.balanceOf(accounts[1]);
        var ethPoolB1 = await web3.eth.getBalance(bo.address);
        await pp.setPrice(basePrice+10);
        await bo.exercise(0);
        var ethB2 = await web3.eth.getBalance(accounts[2]);
        var ethPoolB2 = await web3.eth.getBalance(bo.address);
        console.log(`eth bo balance ${ethPoolB1}, 2 ${ethPoolB2}. ${ethPoolB1 == toWei(9)}`);
        console.log(`eth user balance ${ethB1}, 2 ${ethB2}.`);
        
        assert.equal(
          ethB1 < ethB2,
          true,
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("exercise an put option", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {
        var ethB1 = await web3.eth.getBalance(accounts[2]);
        //var balance = await bo.balanceOf(accounts[1]);
        var ethPoolB1 = await web3.eth.getBalance(bo.address);
        await pp.setPrice(basePrice-10);
        await bo.exercise(1);
        var ethB2 = await web3.eth.getBalance(accounts[2]);
        var ethPoolB2 = await web3.eth.getBalance(bo.address);
        console.log(`eth bo balance ${ethPoolB1}, 2 ${ethPoolB2}. ${ethPoolB1 == toWei(9)}`);
        assert.equal(
          ethB1 < ethB2,
          true,
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("early withdraw from bo", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {

        await bo.stake( { from: accounts[2], value: toWei(9) });
        //await timeTravel(1209700);
        var balance1 = await bo.balanceOf(accounts[2]);
        await bo.withdraw(toWei(9), { from: accounts[2] });
        var balance2 = await bo.balanceOf(accounts[2]);

        assert.equal(
          balance1.toString(),
          "18000000000000000000",
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("withdraw from bo", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {
        await timeTravel(1209700);
        await bo.withdraw(toWei(1), { from: accounts[2] });
        var balance = await bo.balanceOf(accounts[2]);

        assert.equal(
          balance.toString(),
          "8000000000000000000",
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("stake and withdraw small amount without time BinaryOptions", () => {
    return BinaryOptions.deployed().then(async function (bo) {
      return FakePriceProvider.deployed().then(async function (pp) {
        await bo.stake({ from: accounts[3], value: toWei(0.5) });
        var balance1 = await bo.balanceOf(accounts[3]);

        await bo.withdraw(toWei(0.005), { from: accounts[3] });

        var balance2 = await bo.balanceOf(accounts[3]);
        console.log(`balance 1 ${balance1} \nbalance 2 ${balance2}`);
        assert.equal(
          balance1.toString(),
          "500000000000000000",
          "user balance after deposit is zero"
        );
      });
    });
  });
  it("after actions, BIOP balance > 0", () => {
    return BIOPToken.deployed().then(async function (bp) {
      var balance = await bp.balanceOf(accounts[2]);
      assert.equal(
        balance.toString(),
        "1280000000000000000000",
        "user BIOP balance after deposit is zero"
      );
    });
  });
});
