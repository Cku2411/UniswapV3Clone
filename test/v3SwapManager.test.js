const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const { nearestUsableTick } = require("@uniswap/v3-sdk");

describe("UNISWAP V3 MANAGER", () => {
  //deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  // 0x5FbDB2315678afecb367f032d93F642f64180aa3
  // 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
  // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

  let v3Pool,
    v3PoolManager,
    v3PoolQouter,
    v3FactoryofPool,
    token0,
    token1,
    deployer,
    acc1,
    v3PoolAddress,
    v3PoolManagerAddress,
    v3PoolQouterAddress,
    v3FactoryofPoolAddress,
    token0address,
    token1address;

  const testParams = {
    wethBalance: ethers.parseEther("10"),
    usdcBalance: ethers.parseEther("50000"),
    currentTick: 85176,
    lowerTick: nearestUsableTick(84222, 60),
    upperTick: nearestUsableTick(86129, 60),
    liquidity: BigInt(1517882343751509868544),
    currentSqrtP: BigInt(5602277097478614198912276234240),
    shouldTransferInCallback: true,
    mintLiqudity: true,
  };

  // 1517882343751509868544n
  // 741321399860371714442n

  beforeEach(async () => {
    // Get Acount
    const accs = await ethers.getSigners();
    deployer = accs[0];
    acc1 = accs[1];

    // Get Contract Factory
    const tokenFactory = await ethers.getContractFactory("MyToken");
    const v3PoolManagerFactory = await ethers.getContractFactory(
      "UniswapV3Manager"
    );
    const v3PoolQouterFactory = await ethers.getContractFactory(
      "UniswapV3Quoter"
    );
    const v3FactoryofPoolFactory = await ethers.getContractFactory(
      "UniswapV3Factory"
    );

    // Deploy token Contract
    token0 = await tokenFactory.deploy("Ether", "ETH");
    token1 = await tokenFactory.deploy("USDC", "USDC");

    // Get address of deployed tokens contract
    token0address = await token0.getAddress();
    token1address = await token1.getAddress();

    // Deploy Pool Factory
    v3FactoryofPool = await v3FactoryofPoolFactory.deploy();
    v3FactoryofPoolAddress = await v3FactoryofPool.getAddress();
    console.log("Factory Address is", v3FactoryofPoolAddress);

    // Deploy POOL
    const tx = await v3FactoryofPool.createPool(
      token0address,
      token1address,
      "60"
    );

    const txRecipt = await tx.wait();
    v3PoolAddress = await v3FactoryofPool.computeAddress(
      v3FactoryofPoolAddress,
      token0address,
      token1address,
      "60"
    );
    console.log("Pool Address is", v3PoolAddress);
    v3Pool = await ethers.getContractAt("UniswapV3Pool", v3PoolAddress);
    await v3Pool.initialize(testParams.currentSqrtP);

    // DEPLOY MANGAGER AND QUOTER
    v3PoolManager = await v3PoolManagerFactory.deploy(v3FactoryofPoolAddress);
    v3PoolQouter = await v3PoolQouterFactory.deploy(v3FactoryofPoolAddress);

    // Get address of deployed contract
    v3PoolManagerAddress = await v3PoolManager.getAddress();
    v3PoolQouterAddress = await v3PoolQouter.getAddress();

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
      const balancetoken0Before = ethers.formatEther(
        await token0.balanceOf(deployer.address)
      );
      const balancetoken1Before = ethers.formatEther(
        await token1.balanceOf(deployer.address)
      );

      console.log("BalanceToken0 before:", balancetoken0Before);
      console.log("BalanceToken1 before:", balancetoken1Before);

      // MINT LIQUIDITY WITH DEPLOYER
      // const data = ethers.AbiCoder.defaultAbiCoder().encode(
      //   ["address", "address", "address"],
      //   [token0address, token1address, deployer.address]
      // );

      const minPrams = {
        tokenA: token0address,
        tokenB: token1address,
        tickSpacing: "60",
        lowerTick: testParams.lowerTick,
        upperTick: testParams.upperTick,
        amount0Desired: ethers.parseEther("1"),
        amount1Desired: ethers.parseEther("5000"),
        amount0Min: ethers.parseEther("0.9"),
        amount1Min: ethers.parseEther("5000"),
      };

      const mintLiquid = await v3PoolManager.mint(minPrams);
      const mintReciept = await mintLiquid.wait(1);

      // const Checkliquidity = await v3PoolManager.Checkliquidity(minPrams);

      //   //   finding log
      // const logsLength = await mintReciept.logs.length;
      // console.log("mintReciept", mintReciept.logs);
      // console.log("Check mint ", Checkliquidity);
      // console.log("USDC", await mintReciept.logs[logsLength - 1].args);

      const balancetoken0 = ethers.formatEther(
        await token0.balanceOf(deployer.address)
      );
      const balancetoken1 = ethers.formatEther(
        await token1.balanceOf(deployer.address)
      );
      // console.log("BalanceToken0 after:", balancetoken0);
      // console.log("BalanceToken1 after:", balancetoken1);
      console.log("BalanceToken0 change:", balancetoken0 - balancetoken0Before);
      console.log("BalanceToken1 change:", balancetoken1 - balancetoken1Before);

      const slot0 = await v3Pool.slot0();
      console.log("Slot0", slot0);
    });

    it("Quote the price SingleSwap", async () => {
      const slot0 = await v3Pool.slot0();
      const params = {
        tokenIn: token0address,
        tokenOut: token1address,
        tickSpacing: "60",
        pool: v3PoolAddress,
        amountIn: ethers.parseEther("0.01"),
        sqrtPriceLimitX96: "0", //testParams.currentSqrtP,
      };
      const result = await v3PoolQouter.quoteSingle.staticCall(params);
      console.log("result", result);
      console.log("Amount USDT", ethers.formatEther(result[0]));
    });

    xit("Swap within price Range", async () => {
      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [token0address, token1address, deployer.address]
      );
      const swapParams = {
        recipient: deployer.address,
        zeroForOne: true, //Swap direction
        amountSpecified: ethers.parseEther("0.01"), // amount want to sell
        sqrtPriceLimitX96: testParams.currentSqrtP, //Slippage price
        data: data,
      };

      const result = await v3PoolManager.swap(
        swapParams.recipient,
        swapParams.zeroForOne,
        swapParams.amountSpecified,
        swapParams.sqrtPriceLimitX96,
        swapParams.data
      );

      await result.wait();
    });

    // it("Ok", async () => {
    //   console.log("HHHHHH");
    // });
  });
});
