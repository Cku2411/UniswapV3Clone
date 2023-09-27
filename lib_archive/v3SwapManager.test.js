const { assert, expect } = require("chai");
const { ECDH } = require("crypto");
const { ethers } = require("hardhat");

describe("UNISWAP V3 MANAGER", () => {
  //deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  // 0x5FbDB2315678afecb367f032d93F642f64180aa3
  // 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
  // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

  let v3Pool,
    token0,
    token1,
    deployer,
    acc1,
    v3PoolAddress,
    v3PoolManager,
    v3PoolManagerAddress,
    token0address,
    token1address;

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
    // Get Acount
    const accs = await ethers.getSigners();
    deployer = accs[0];
    acc1 = accs[1];

    // Get Contract Factory
    const v3PoolFactory = await ethers.getContractFactory("UniswapV3Pool");
    const tokenFactory = await ethers.getContractFactory("MyToken");
    const v3PoolManagerFactory = await ethers.getContractFactory(
      "UniswapV3Manager"
    );

    // Deploy all contract
    token0 = await tokenFactory.deploy("Ether", "ETH");
    token1 = await tokenFactory.deploy("USDC", "USDC");

    // Get address of deployed contract
    token0address = await token0.getAddress();
    token1address = await token1.getAddress();

    v3Pool = await v3PoolFactory.deploy(
      token0address,
      token1address,
      testParams.currentSqrtP,
      testParams.currentTick
    );
    v3PoolManager = await v3PoolManagerFactory.deploy();

    // Get address of deployed contract
    v3PoolAddress = await v3Pool.getAddress();
    v3PoolManagerAddress = await v3PoolManager.getAddress();

    // MInt token0, token1 to deployer
    await token0.mint(deployer.address, testParams.wethBalance);
    await token1.mint(deployer.address, testParams.usdcBalance);

    const balancetoken0 = await token0.balanceOf(deployer.address);
    const balancetoken1 = await token1.balanceOf(deployer.address);

    // approve deployer to V3Poolmanager
    await token0.approve(v3PoolManagerAddress, balancetoken0);
    await token1.approve(v3PoolManagerAddress, balancetoken1);
  });

  describe("Testing POOL ", () => {
    beforeEach(async () => {
      // MINT LIQUIDITY WITH DEPLOYER

      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [token0address, token1address, deployer.address]
      );

      const mintLiquid = await v3PoolManager.mint(
        v3PoolAddress,
        testParams.lowerTick,
        testParams.upperTick,
        testParams.liquidity,
        data
      );

      const mintReciept = await mintLiquid.wait(1);
      //   //   finding log
      //   //   const logsLength = await mintReciept.logs.length;
      //   //   console.log("USDC", await mintReciept.logs[4].args[6]);
    });

    it("Should deposit expected Amount", async () => {
      const expectAmountETHER = ethers.parseEther("0.998976618347425280");
      const expectAmountUSDC = ethers.parseEther("5000");
      expect(await token0.balanceOf(v3PoolAddress)).to.be.equal(
        expectAmountETHER
      );
      expect(await token1.balanceOf(v3PoolAddress)).to.be.equal(
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
      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [token0address, token1address, acc1.address]
      );
      //   expect revert with Zero
      await expect(
        v3PoolManager
          .connect(acc1)
          .mint(
            v3PoolAddress,
            testParams.lowerTick,
            testParams.upperTick,
            0,
            data
          )
      ).to.be.revertedWithCustomError(v3Pool, "ZeroLiquidity()");
    });

    it("faild with Tick range", async () => {
      const ticklower = -887277;

      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [token0address, token1address, acc1.address]
      );
      //   expect revert with tickrange
      await expect(
        v3PoolManager
          .connect(acc1)
          .mint(
            v3PoolAddress,
            ticklower,
            testParams.upperTick,
            testParams.liquidity,
            data
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
      //encode data

      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [token0address, token1address, acc1.address]
      );

      const token1Acc1 = await token1.connect(acc1);
      const v3PoolManagerAcc1 = await v3PoolManager.connect(acc1);
      // mint 42 usde to acc1
      await token1Acc1.mint(acc1.address, ethers.parseEther("42"));
      const amountSwapUSDC = await token1Acc1.balanceOf(acc1.address);

      // swap 42usd to ETH
      await token1Acc1.approve(v3PoolManagerAddress, amountSwapUSDC);
      await v3PoolManagerAcc1.swap(v3PoolAddress, data);

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
