// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// import "./IUniswapV3Pool.sol";

interface IUniswapV3Pool {
    struct CallbackData {
        address token0;
        address token1;
        address player;
    }

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        address recipient,
        bool zeroForOne, //Swap direction
        uint256 amountSpecified, // amount want to sell
        uint160 sqrtPriceLimitX96, //Slippage price
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function slot0()
        external
        view
        returns (uint160, int24, uint16, uint16, uint16);

    function token0() external view returns (address);

    function token1() external view returns (address);

    // function CallbackData(DataCallback calldata _callbackData) external;
}
