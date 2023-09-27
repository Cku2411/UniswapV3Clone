// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount10wed,
        bytes calldata data
    ) external;
}
