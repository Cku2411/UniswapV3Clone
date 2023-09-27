// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./SqrtPriceMath.sol";
import "./FullMath.sol";

library SwapMath {
    /// @notice Computes the result of swapping some amount in, or amount out, given the parameters of the swap
    /// @dev The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
    /// @param sqrtRatioCurrentX96 The current sqrt price of the pool
    /// @param sqrtRatioTargetX96 The price that cannot be exceeded, from which the direction of the swap is inferred
    /// @param liquidity The usable liquidity
    /// @param amountRemaining How much input or output amount is remaining to be swapped in/out
    /// @param feePips The fee taken from the input amount, expressed in hundredths of a bip
    /// @return sqrtRatioNextX96 The price after swapping the amount in/out, not to exceed the price target
    /// @return amountIn The amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return amountOut The amount to be received, of either token0 or token1, based on the direction of the swap
    /// @return feeAmount The amount of input that will be taken as a fee
    // function computeSwapStep(
    //     uint160 sqrtRatioCurrentX96,
    //     uint160 sqrtRatioTargetX96,
    //     uint128 liquidity,
    //     int256 amountRemaining,
    //     uint24 feePips
    // )
    //     internal
    //     pure
    //     returns (
    //         uint160 sqrtRatioNextX96,
    //         uint256 amountIn,
    //         uint256 amountOut,
    //         uint256 feeAmount
    //     )
    // {
    //     // Define the trade from 0 to 1
    //     bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
    //     // Define where is ther trade is exact or not
    //     bool exactIn = amountRemaining >= 0;
    //     // calculate max amount in or out and next sqrt ration
    //     if (exactIn) {
    //         uint amountRemainingLessFee = FullMath.mulDiv(
    //             uint256(amountRemaining),
    //             1e6 - feePips,
    //             1e6
    //         );
    //         // Calculate max amount in, round up adn amount in
    //         amountIn = zeroForOne
    //             ? SqrtPriceMath.getAmount0Delta(
    //                 sqrtRatioTargetX96,
    //                 sqrtRatioCurrentX96,
    //                 liquidity,
    //                 true
    //             )
    //             : SqrtPriceMath.getAmount1Delta(
    //                 sqrtRatioCurrentX96,
    //                 sqrtRatioTargetX96,
    //                 liquidity,
    //                 true
    //             );
    //         // Calculate next sqrt Ration
    //     } else {}
    // }
}
