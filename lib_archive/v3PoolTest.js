const { assert, expect } = require("chai");
const { ethers } = require("hardhat");

// TEST TOKEN
describe("V3Pool test", () => {
  //deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  let v3Pool, token0, token1, deployer, acc1, v3PoolAddress;

  const testParams = {
    wethBalance: ethers.parseEther("1"),
    usdcBalance: ethers.parseEther("5000"),
    currentTick: 85176,
    lowerTick: 84222,
    upperTick: 86129,
    liquidity: BigInt(1517882343751509868544),
    currentSqrtP: BigInt(5602277097478614198912276234240),
    shouldTransferInCallback: true,
    mintLiqudity: true,
  };

  beforeEach(async () => {
    const accs = await ethers.getSigners();
    deployer = accs[0];
    acc1 = accs[1];

    const v3PoolFactory = await ethers.getContractFactory("UniswapV3Pool");
    const tokenFactory = await ethers.getContractFactory("MyToken");

    token0 = await tokenFactory.deploy("Ether", "ETH");
    token1 = await tokenFactory.deploy("USDC", "USDC");

    const token0address = await token0.getAddress();
    const token1address = await token1.getAddress();

    v3Pool = await v3PoolFactory.deploy(
      token0address,
      token1address,
      testParams.currentSqrtP,
      testParams.currentTick
    );

    v3PoolAddress = await v3Pool.getAddress();

    // console.log("Function mint", await token0.getFunction("mint"));
    // console.log("address Token 2", token1address);
    // console.log("address V3pool", await v3Pool.getAddress());
    // console.log("liquidity", testParams.currentSqrtP);

    // MInt token0
    await token0.mint(deployer.address, testParams.wethBalance);
    await token1.mint(deployer.address, testParams.usdcBalance);

    const balancetoken0 = await token0.balanceOf(deployer.address);
    const balancetoken1 = await token1.balanceOf(deployer.address);

    // approve
    await token0.approve(await v3Pool.getAddress(), balancetoken0);
    await token1.approve(await v3Pool.getAddress(), balancetoken1);
    await token0
      .connect(acc1)
      .approve(await v3Pool.getAddress(), balancetoken0);
    await token1
      .connect(acc1)
      .approve(await v3Pool.getAddress(), balancetoken1);
  });

  //   it("Should mint 1ETH and 5000 USD ", async () => {
  //     // MInt token0
  //     await token0.mint(deployer.address, testParams.wethBalance);
  //     await token1.mint(deployer.address, testParams.usdcBalance);

  //     const balancetoken0 = await token0.balanceOf(deployer.address);
  //     const balancetoken1 = await token1.balanceOf(deployer.address);

  //     // approve
  //     await token0.approve(await v3Pool.getAddress(), balancetoken0);
  //     await token1.approve(await v3Pool.getAddress(), balancetoken1);

  //     expect(balancetoken0).to.be.equal(testParams.wethBalance);
  //     expect(balancetoken1).to.be.equal(testParams.usdcBalance);
  //   });

  describe("Success Case", () => {
    beforeEach(async () => {
      const mintLiquid = await v3Pool.mint(
        deployer.address,
        testParams.lowerTick,
        testParams.upperTick,
        testParams.liquidity
      );
      const mintReciept = await mintLiquid.wait(1);
      //   const logsLength = await mintReciept.logs.length;
      //   console.log("USDC", await mintReciept.logs[4].args[6]);
    });

    it("Should deposit expected Amount", async () => {
      const expectAmountETHER = ethers.parseEther("0.998976618347425280");
      const expectAmountUSDC = ethers.parseEther("5000");

      expect(await token0.balanceOf(await v3Pool.getAddress())).to.be.equal(
        expectAmountETHER
      );

      expect(await token1.balanceOf(await v3Pool.getAddress())).to.be.equal(
        expectAmountUSDC
      );
    });

    it("Check liquidity", async () => {
      // Hash keccak(abi.encodepacked)
      const etherhash = ethers.solidityPackedKeccak256(
        ["address", "int24", "int24"],
        [deployer.address, testParams.lowerTick, testParams.upperTick]
      );

      const liquidity = await v3Pool.positions(etherhash);
      expect(liquidity).to.be.equal(testParams.liquidity);
    });

    it("Check ticks", async () => {
      // call lowerTick
      const lowerTick = await v3Pool.ticks(testParams.lowerTick);
      //   Tick lower

      const tickInitialized = lowerTick[0];
      const tickLowerLiquidity = lowerTick[1];

      expect(tickInitialized).to.be.equal(true);
      expect(tickLowerLiquidity).to.be.equal(testParams.liquidity);

      // tick upper
      const upperTick = await v3Pool.ticks(testParams.upperTick);

      const tickInitializedUpper = lowerTick[0];
      const tickUpperLiquidity = lowerTick[1];

      expect(tickInitializedUpper).to.be.equal(true);
      expect(tickUpperLiquidity).to.be.equal(testParams.liquidity);
    });

    it("Check Price and liquidity", async () => {
      // check liquidity
      const liquidity = await v3Pool.liquidity();
      expect(liquidity).to.be.equal(testParams.liquidity);

      //   check price

      const slot0 = await v3Pool.slot0();
      expect(slot0[0]).to.be.equal(testParams.currentSqrtP);
      expect(slot0[1]).to.be.equal(testParams.currentTick);
    });

    it("faild with zero liquidity", async () => {
      //   expect revert with Zero
      await expect(
        v3Pool
          .connect(acc1)
          .mint(acc1.address, testParams.lowerTick, testParams.upperTick, 0)
      ).to.be.revertedWithCustomError(v3Pool, "ZeroLiquidity()");
    });

    it("faild with Tick range", async () => {
      const ticklower = -887277;

      await expect(
        v3Pool
          .connect(acc1)
          .mint(
            acc1.address,
            ticklower,
            testParams.upperTick,
            testParams.liquidity
          )
      ).to.be.revertedWithCustomError(v3Pool, "InvalidTickRange()");
    });

    // it("Insufficient token", async () => {
    //   await expect(
    //     v3Pool
    //       .connect(acc1)
    //       .mint(
    //         acc1.address,
    //         testParams.lowerTick,
    //         testParams.upperTick,
    //         testParams.liquidity
    //       )
    //   ).to.be.revertedWithCustomError(v3Pool, "InsufficientInputAmount()");
    // });

    it("success full swap", async () => {
      const token1Acc1 = await token1.connect(acc1);
      const v3PoolAcc1 = await v3Pool.connect(acc1);
      // mint 42 usde to acc1
      await token1Acc1.mint(acc1.address, ethers.parseEther("42"));
      const amountSwapUSDC = await token1Acc1.balanceOf(acc1.address);

      // swap 42usd to ETH
      await token1Acc1.approve(v3PoolAddress, amountSwapUSDC);
      await v3PoolAcc1.swap(acc1.address);

      const amountSwapUSDCAfter = await token1Acc1.balanceOf(acc1.address);
      const amountSwapUSDCPOOLAfter = await token1Acc1.balanceOf(v3PoolAddress);
      const expectETHAmountOUt = ethers.parseEther("0.008396714242162444");
      const ETHAMOUNT = await token0.balanceOf(acc1.address);

      const ExpectPrice = 5604469350942327889444743441197n;
      const ExpectTick = BigInt(85184);
      const slot0 = await v3Pool.slot0();

      // CHECK
      expect(ETHAMOUNT).to.be.equal(expectETHAmountOUt);
      expect(slot0[1]).to.be.equal(ExpectTick);
      expect(slot0[0].toString()).to.be.equal(ExpectPrice.toString());
    });
  });
});
