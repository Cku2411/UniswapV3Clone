// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./FixedPoint96.sol";
import "./FixedPoint128.sol";
import "./FullMath.sol";

library Math {
    // 🔺x
    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        // if it bigger it will be uppber range
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        require(sqrtPriceAX96 > 0);
        amount0 = divRoundingUp(
            mulDivRoundingUp(
                (uint256(liquidity) << FixedPoint96.RESOLUTION),
                (sqrtPriceBX96 - sqrtPriceAX96),
                sqrtPriceBX96
            ),
            sqrtPriceAX96
        );
    }

    // 🔺Y

    function calcAmount1Delta(
        uint160 sqrtPriceAX96, //pricetoken0
        uint160 sqrtPriceBX96, // pricetoken1
        uint128 liquidity //liquidity
    ) internal pure returns (uint256 amount1) {
        // reOrder of price
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        amount1 = mulDivRoundingUp(
            liquidity,
            (sqrtPriceBX96 - sqrtPriceAX96),
            FixedPoint96.Q96
        );
    }

    // HELPER FUNCTION
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // (a*b) / k
        result = FullMath.mulDiv(a, b, denominator);
        // (a*b) % k
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            // if the remainder > 0 => round the result.
            result++;
        }
    }

    // Rounding phep chia
    function divRoundingUp(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        assembly {
            result := add(
                div(numerator, denominator),
                gt(mod(numerator, denominator), 0)
            )
        }
    }

    // Finding price by Swap amount
    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        sqrtPriceNextX96 = zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            )
            : getNextSqrtPriceFromAmount1RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            );
    }

    // MeanWhile
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        // tu so  = L  * 2 ^ 96
        uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;

        uint256 product = amountIn * sqrtPriceX96;

        if (product / amountIn == sqrtPriceX96) {
            uint256 denominator = numerator + product;

            // Check overflows
            if (denominator >= numerator) {
                return
                    uint160(
                        mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
                    );
            }

            // otherWise
            return
                uint160(
                    divRoundingUp(
                        numerator,
                        (numerator / sqrtPriceX96) + amountIn
                    )
                );
        }
    }

    function getNextSqrtPriceFromAmount1RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        return
            sqrtPriceX96 +
            uint160((amountIn << FixedPoint96.RESOLUTION) / liquidity);
    }
}
