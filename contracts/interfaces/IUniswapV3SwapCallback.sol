// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Owed,
        int256 amount10wed,
        bytes calldata data
    ) external;
}
