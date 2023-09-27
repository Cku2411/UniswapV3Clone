// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./UniswapV3PoolClone.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "../lib/TickMath.sol";
import "../lib/LiquidityMath.sol";
import "../lib/Path.sol";
import "../lib/PoolAddress.sol";
import "hardhat/console.sol";

error SlippageCheckFailed(uint256 amount0, uint256 amoun1);
error TooLittleReceived(uint256 amountOut);

contract UniswapV3Manager {
    using Path for bytes;
    address public immutable factory;

    // Struct for mint calculation
    struct MintParams {
        address tokenA;
        address tokenB;
        uint24 tickSpacing;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct SwapSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 tickSpacing;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    // Multi-Pool Swap
    struct SwapParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 minAmountOut;
    }

    // Swap data structure
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    // CONSTRUCTOR
    constructor(address _factory) {
        factory = _factory;
    }

    function mint(
        MintParams calldata params
    ) public returns (uint256 amount0, uint256 amount1) {
        // Caculate pool address and make a new Instance of POOL
        address poolAddress = PoolAddress.computeAddress(
            factory,
            params.tokenA,
            params.tokenB,
            params.tickSpacing
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Get the current Price
        (uint160 sqrtPriceX96, ) = pool.slot0();
        // Get Price Range
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.lowerTick
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.upperTick
        );

        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0Desired,
            params.amount1Desired
        );

        bytes memory data = abi.encode(
            IUniswapV3Pool.CallbackData({
                token0: pool.token0(),
                token1: pool.token1(),
                player: msg.sender
            })
        );

        console.log("OKIE, let's mint  %s  %s", liquidity, sqrtPriceLowerX96);

        (amount0, amount1) = pool.mint(
            msg.sender,
            params.lowerTick,
            params.upperTick,
            liquidity,
            data
        );

        //  Check the amounts returns by the pool, if they too low, we revert
        // if (amount0 < params.amount0Min || amount1 < params.amount1Min) {
        //     revert SlippageCheckFailed(amount0, amount1);
        // }
    }

    // ---------SWAP
    // MULTIPLE POOL SWAP
    function swap(SwapParams memory params) public returns (uint256 amountOut) {
        address payer = msg.sender;
        bool hasMultiplePools;

        while (true) {
            hasMultiplePools = params.path.hasMultiplePools();
            // loop amountIn
            //  first swap amountIn is provided by user, next swap is amountreturn from previous swap
            params.amountIn = _swap(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient,
                0,
                SwapCallbackData({
                    path: params.path.getFirstPool(),
                    payer: payer
                })
            );

            // Check if the path is end or not

            if (hasMultiplePools) {
                payer = address(this);
                params.path = params.path.skipToken();
            } else {
                amountOut = params.amountIn;
                break;
            }
        }

        // Slipage protection
        if (amountOut < params.minAmountOut)
            revert TooLittleReceived(amountOut);
    }

    // Single-Pool swap is a multipulSwap with onePool
    function swapSingle(
        SwapSingleParams calldata params
    ) public returns (uint256 amountOut) {
        amountOut = _swap(
            params.amountIn,
            msg.sender,
            params.sqrtPriceLimitX96,
            SwapCallbackData({
                path: abi.encodePacked(
                    params.tokenIn,
                    params.tickSpacing,
                    params.tokenOut
                ),
                payer: msg.sender
            })
        );
    }

    // INTERNAL
    function _swap(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) internal returns (uint256 amountOut) {
        // Extracting pool parameters
        (address tokenIn, address tokenOut, uint24 tickSpacing) = data
            .path
            .decodeFirstPool();

        // indentify swap direction
        bool zeroForOne = tokenIn < tokenOut;

        // Make the actual swap
        (int256 amount0, int256 amount1) = getPool(
            tokenIn,
            tokenOut,
            tickSpacing
        ).swap(
                recipient,
                zeroForOne,
                amountIn,
                sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        // find amount0 based on Swap direction
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }

    // HELPER FUNCTION
    function Checkliquidity(
        // address poolAddress,
        // int24 lowerTick,
        // int24 upperTick,
        // uint128 liquidity,
        // bytes calldata data
        MintParams calldata params
    )
        public
        view
        returns (uint128, uint160, uint160, uint256 amount0, uint256 amount1)
    {
        // Caculate pool address and make a new Instance of POOL
        address poolAddress = PoolAddress.computeAddress(
            factory,
            params.tokenA,
            params.tokenB,
            params.tickSpacing
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.lowerTick
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.upperTick
        );

        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0Desired,
            params.amount1Desired
        );

        // CALCULATE

        if (tick < params.lowerTick) {
            amount0 = Math.calcAmount0Delta(
                sqrtPriceX96, //current price
                TickMath.getSqrtRatioAtTick(params.upperTick),
                liquidity // liquidity
            );
        } else if (tick < params.upperTick) {
            amount0 = Math.calcAmount0Delta(
                sqrtPriceX96, //current price
                TickMath.getSqrtRatioAtTick(params.upperTick),
                liquidity // liquidity
            );

            amount1 = Math.calcAmount1Delta(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                liquidity // liquidity
            );
        } else {
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                liquidity // liquidity
            );
        }

        return (
            liquidity,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            amount0,
            amount1
        );
    }

    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal view returns (IUniswapV3Pool pool) {
        // sort the token
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);

        //  make instance  Pool IUniswapV3Pool(address Pool);
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, tickSpacing)
        );
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        // decode data to struct CallbackData
        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.player, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.player, msg.sender, amount1);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        // decode data to struct CallbackData
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(
                extra.player,
                msg.sender,
                uint256(amount0)
            );
        }

        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(
                extra.player,
                msg.sender,
                uint256(amount1)
            );
        }
    }
}
