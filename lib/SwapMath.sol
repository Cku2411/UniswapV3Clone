// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Math.sol";
import "./FullMath.sol";

library SwapMath {
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint256 fee
    )
        internal
        pure
        returns (
            uint160 sqrtPriceNext96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        // Find Swap direction
        bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;
        uint256 amountRemainingLessFee = FullMath.mulDiv(
            amountRemaining,
            1e6 - fee,
            1e6
        );

        amountIn = zeroForOne
            ? Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity
            )
            : Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity
            );

        if (amountRemainingLessFee >= amountIn)
            sqrtPriceNext96 = sqrtPriceTargetX96;
        else {
            sqrtPriceNext96 = Math.getNextSqrtPriceFromInput(
                sqrtPriceCurrentX96,
                liquidity,
                amountRemainingLessFee,
                zeroForOne
            );

            amountIn = Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNext96,
                liquidity
            );
            amountOut = Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNext96,
                liquidity
            );
        }

        bool max = sqrtPriceNext96 == sqrtPriceTargetX96;
        if (!max) {
            feeAmount = amountRemaining - amountIn;
        } else {
            feeAmount = Math.mulDivRoundingUp(amountIn, fee, 1e6 - fee);
        }

        // Swap the amounts if the direction is opposite;

        if (!zeroForOne) {
            (amountIn, amountOut) = (amountOut, amountIn);
        }
    }
}
