// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IUniswapV3Pool.sol";
import "../lib/TickMath.sol";
import "../lib/PoolAddress.sol";
import "../lib/Path.sol";
import "hardhat/console.sol";

contract UniswapV3Quoter {
    using Path for bytes;

    struct QuoteSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 tickSpacing;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    address public immutable factory;

    // Constructor
    constructor(address _factory) {
        factory = _factory;
    }

    // Main Function
    function quoteSingle(
        QuoteSingleParams memory params
    )
        public
        returns (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter)
    {
        console.log("OKie let's start...");
        IUniswapV3Pool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.tickSpacing
        );

        console.log("Pool Address is. %s..", address(pool));

        bool zeroForOne = params.tokenIn < params.tokenOut;
        console.log(" zeroForOne?? %s...", zeroForOne);
        console.log(" AmountIN? %s...", params.amountIn);
        console.log(" sqrtPriceLimitX96? %s...", params.sqrtPriceLimitX96);

        // Simulation swap
        console.log("Simutation Swap...");
        try
            pool.swap(
                address(this),
                zeroForOne,
                params.amountIn,
                // Check sqrtPriceLimitX96
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MIN_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encode(address(pool))
            )
        {} catch (bytes memory reason) {
            // catch the bytes return from callBack fucntion and decode it.
            return abi.decode(reason, (uint256, uint160, int24));
        }
    }

    function quote(
        bytes memory path,
        uint256 amountIn
    )
        public
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            int24[] memory tickAfterList
        )
    {
        // Make new array of price and tick with the leng == number of Pools
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        tickAfterList = new int24[](path.numPools());

        uint256 i = 0;
        // Looping through pool
        while (true) {
            (address tokenIn, address tokenOut, uint24 tickSpacing) = path
                .decodeFirstPool();

            (
                uint256 amountOut_,
                uint160 sqrtPriceX96After,
                int24 tickAfter
            ) = quoteSingle(
                    QuoteSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        tickSpacing: tickSpacing,
                        amountIn: amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );

            // add result to array
            sqrtPriceX96AfterList[i] = sqrtPriceX96After;
            tickAfterList[i] = tickAfter;
            amountIn = amountOut_;
            i++;

            if (path.hasMultiplePools()) {
                path = path.skipToken();
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }

    // CALLBACK FUNCTION

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        address pool = abi.decode(data, (address));

        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)
            : uint256(-amount0Delta);

        (uint160 sqrtPriceX96After, int24 tickAfter, , , ) = IUniswapV3Pool(
            pool
        ).slot0();

        // Save the value and revert
        //  this things equal = abi.encode()
        assembly {
            let ptr := mload(0x40) //read pointer at location netx 64 bytes 0x40()
            // at that memory slot writes amountOut
            mstore(ptr, amountOut)
            // writes sqrtPrice after amountOut at next32bytes 0x20  (amount0 take 0x20 - 32 bytes)
            mstore(add(ptr, 0x20), sqrtPriceX96After)

            // writes tickAfter after sqrtPrice at location next 32 bytes 0x40 - 64bytes from pointer
            mstore(add(ptr, 0x40), tickAfter)
            // revert the call and returns 96 bytes -0x60
            revert(ptr, 96)
        }
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
}
