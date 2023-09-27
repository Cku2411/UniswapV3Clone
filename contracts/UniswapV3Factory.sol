// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3PoolClone.sol";

error TokensMustBeDifferent();
error UnsupportedFee();
error ZeroAddressNotAllowed();
error PoolAlreadyExists();

contract UniswapV3Factory is IUniswapV3PoolDeployer {
    PoolParameters public parameters;

    // Mapping
    // mapping(uint24 => bool) public tickSpacings;
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;
    // Mapping fee to tickSpacing
    mapping(uint24 => uint24) public fees;

    // event
    event PoolCreated(
        address token0,
        address token1,
        uint24 tickSpacings,
        address pool
    );

    /**CONSTRUCTOR
     * Setup tickspacing*/
    constructor() {
        fees[500] = 10;
        fees[3000] = 60;
    }

    // MAIN FUNCTION

    function createPool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) public returns (address pool) {
        // Check tokenPool must be different
        if (tokenX == tokenY) revert TokensMustBeDifferent();
        // Check if tickSpacing is valide be 10 or 60
        if (fees[fee] == 0) revert UnsupportedFee();

        // Sorting token (token can be sorted because it's hex format)
        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        // Check address0, we don't need to check tokenY because tokens are sorted so TokenX is alwasy smallest
        if (tokenX == address(0)) revert ZeroAddressNotAllowed();

        // Check if pool exist or not
        if (pools[tokenX][tokenY][fee] != address(0))
            revert PoolAlreadyExists();

        //  Set Pool Parameters
        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: fees[fee],
            fee: fee
        });

        // creat new UniswapV3Pool()  with specific salt option using CREAT2- SOLIDITY
        // salt: bytes32 = keccak256(abi.encodePacked(tokenX, tokenY, tickSpacing))
        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encodePacked(tokenX, tokenY, fee))
            }()
        );

        // Keep Pool in mapping
        pools[tokenX][tokenY][fee] = pool;
        pools[tokenY][tokenX][fee] = pool;

        // remover parametes;
        delete parameters;

        // emit event
        emit PoolCreated(tokenX, tokenY, fee, pool);
    }

    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 tickSpacing
    ) external pure returns (address pool) {
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
