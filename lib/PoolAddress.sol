// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../contracts/UniswapV3PoolClone.sol";

library PoolAddress {
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal pure returns (address pool) {
        // Expect Tokens to be sorted
        require(token0 < token1);

        // identified contraact address EIP-1014
        // (0xff, deployerAddress, Salt(token1, token2, tickSpacing), contractCode)
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", // used for CREATE2
                            factory, // deployer in our case
                            keccak256(
                                abi.encodePacked(token0, token1, tickSpacing)
                            ), // salt
                            keccak256(type(UniswapV3Pool).creationCode) // contract code
                        )
                    )
                )
            )
        );
    }
}
