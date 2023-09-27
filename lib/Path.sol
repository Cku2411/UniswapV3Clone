// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BytesLib.sol";

library Path {
    using BytesLib for bytes;
    ///@dev The length the bytes encoded address
    uint256 private constant ADDR_SIZE = 20;
    /// @dev the length the bytes encoded tick spacing
    uint24 private constant TICKSPACING_SIZE = 3;
    /// @dev The offset of a single token address + tick Spacing
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + TICKSPACING_SIZE;
    /// @dev The offset of encoded pool keys (tokenIn + tickSpacing + tokenOut)
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    /// @dev the minimum length of a path that contains 2 or more pools
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH =
        POP_OFFSET + NEXT_OFFSET;

    function numPools(bytes memory path) internal pure returns (uint256) {
        return (path.length - ADDR_SIZE) / NEXT_OFFSET;
    }

    // Check if path has multiple Pool
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    // Extracting first Pool parameters from a Path
    // Return the first "Token address + tick Spacing + tokenAddress"
    function getFirstPool(
        bytes memory path
    ) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length);
    }

    // Decode parameters of the first pool
    function decodeFirstPool(
        bytes memory path
    )
        internal
        pure
        returns (address tokenIn, address tokenOut, uint24 tickSpacing)
    {
        tokenIn = path.toAddress(0);
        tickSpacing = path.toUint24(ADDR_SIZE);
        tokenOut = path.toAddress(NEXT_OFFSET);
    }
}
