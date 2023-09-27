// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

// examples

// function uniswapV3FlashCallback(bytes calldata data) public {
//     (uint256 amount0, uint256 amount1) = abi.decode(data, (uint256, uint256));

//     if (amount0 > 0) token0.transfer(msg.sender, amount0);
//     if (amount1 > 0) token1.transfer(msg.sender, amount1);
// }
