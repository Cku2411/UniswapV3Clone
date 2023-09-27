// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

import "./FullMath.sol";
import "./FixedPoint96.sol";

library LiquidityMath {
    function addLiquidity(
        uint128 liquidity,
        int128 amount
    ) internal pure returns (uint128 newLiquidity) {
        if (amount < 0) {
            newLiquidity = liquidity - uint128(-amount);
        } else {
            newLiquidity = liquidity + uint128(amount);
        }
    }

    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceLowerX96 > sqrtPriceUpperX96) {
            (sqrtPriceLowerX96, sqrtPriceUpperX96) = (
                sqrtPriceUpperX96,
                sqrtPriceLowerX96
            );
        }

        // if liquidity for the range above current Price
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            liquidity = getLiquidityForAmount0(
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                amount0Desired
            );
        }
        // if the current Price within the range pick smaller one
        else if (sqrtPriceX96 <= sqrtPriceUpperX96) {
            uint128 liquidity0 = getLiquidityForAmount0(
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                amount0Desired
            );

            uint128 liquidity1 = getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                amount1Desired
            );
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
        // if the range below current Price
        else {
            liquidity = getLiquidityForAmount1(
                sqrtPriceLowerX96,
                sqrtPriceUpperX96,
                amount1Desired
            );
        }
    }

    // Liquidity Calculation for TokenX
    function getLiquidityForAmount0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0 // Liquidity
    ) internal pure returns (uint128 liquidity) {
        // set range PRice
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }
        // i = (pa * pb)/q96
        uint256 intermediate = FullMath.mulDiv(
            sqrtPriceAX96,
            sqrtPriceBX96,
            FixedPoint96.Q96
        );

        // amount * i/(pb - pa)
        liquidity = uint128(
            FullMath.mulDiv(
                amount0,
                intermediate,
                sqrtPriceBX96 - sqrtPriceAX96
            )
        );
    }

    // Liquidity Calculation for TokenY
    function getLiquidityForAmount1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount1 // Liquidity
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        liquidity = uint128(
            FullMath.mulDiv(
                amount1,
                FixedPoint96.Q96,
                sqrtPriceBX96 - sqrtPriceAX96
            )
        );
    }
}
