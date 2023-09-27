// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LiquidityMath.sol";
import "hardhat/console.sol";

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidityGross; //track the absolute liquidity amount of tick
        int128 liquidityNet; // tracks the amount of liquidity added or removed when tick is crossed
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }

    // Helper function

    function update(
        mapping(int24 => Tick.Info) storage self, //using for this type storage to get
        int24 tick,
        int24 currentTick,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper
    ) internal returns (bool flipped) {
        // Get info from mapping
        Tick.Info storage tickInfo = self[tick];
        uint128 liquidityBefore = tickInfo.liquidityGross;
        // Update liquidity
        uint128 liquidityAfer = LiquidityMath.addLiquidity(
            liquidityBefore,
            liquidityDelta
        );

        // Flipped is set true when liquidity is added to an empty tick or when entire liquidity is removed from a tick
        flipped = (liquidityAfer == 0) != (liquidityBefore == 0);

        // Check if it has liquidity nefore
        if (liquidityBefore == 0) {
            if (tick <= currentTick) {
                tickInfo.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                tickInfo.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
            tickInfo.initialized = true;
        }

        tickInfo.liquidityGross = liquidityAfer;
        tickInfo.liquidityNet = upper
            ? int128(int256(tickInfo.liquidityNet) - liquidityDelta)
            : int128(int256(tickInfo.liquidityNet) + liquidityDelta);
    }

    //returns liquidityNet
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 =
            feeGrowthGlobal0X128 -
            info.feeGrowthOutside0X128;

        info.feeGrowthOutside1X128 =
            feeGrowthGlobal1X128 -
            info.feeGrowthOutside1X128;

        int128 liquidityDelta = info.liquidityNet;
        return liquidityDelta;
    }

    // Update Positions Fees and TokenAMounts
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 _lowerTick,
        int24 _upperTick,
        int24 currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        Tick.Info storage lowerTick = self[_lowerTick];
        Tick.Info storage upperTick = self[_upperTick];

        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;

        if (currentTick >= _lowerTick) {
            feeGrowthBelow0X128 = lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lowerTick.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 =
                feeGrowthBelow0X128 -
                lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthBelow1X128 -
                lowerTick.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;

        if (currentTick < _upperTick) {
            feeGrowthAbove0X128 = upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upperTick.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 =
                feeGrowthAbove0X128 -
                upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 =
                feeGrowthAbove1X128 -
                upperTick.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 =
            feeGrowthGlobal0X128 -
            feeGrowthBelow0X128 -
            feeGrowthAbove0X128;

        feeGrowthInside1X128 =
            feeGrowthGlobal1X128 -
            feeGrowthBelow1X128 -
            feeGrowthAbove1X128;
    }
}
