// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "solmate/src/tokens/ERC721.sol";

contract UniswapV3NFTManager is ERC721 {
    address public immutable factory;

    // struc to keep links between pool liquidity and NFTs
    struct TokenPosition {
        address pool;
        int24 lowerTick;
        int24 upperTick;
    }

    struct MintParams {
        address recipient;
        address tokenA;
        address tokenB;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    // Mapping
    mapping(uint256 => TokenPosition) public positions;

    // Constructor

    constructor(
        address factoryAddress
    ) ERC721("UniswapV3 NFT Positions", "UNIV3") {
        factory = factoryAddress;
    }

    function mint(MintParams calldata params) public returns (uint256 tokenId) {
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);
    }

    // Helper Function
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return "";
    }
}
