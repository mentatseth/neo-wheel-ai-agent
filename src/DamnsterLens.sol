// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INonfungiblePositionManager, IUniswapV3Factory, ExactInputSingleParams, ExactInputParams, ISwapRouter, MintParams, IQuoterV2} from "./interfaces/UniInterface.sol";
import {DamnsterToken} from "./DamnsterToken.sol";
import {TickMath} from "./TickMath.sol";
import {AddressStorage} from "./AddressStorage.sol";

interface IDamnsterFactory {
    function bundleFeeSwitch() external view returns(bool);
    function taxRate() external view returns(uint256);
}

contract DamnsterLens is Ownable, AddressStorage {
    using TickMath for int24;

    address public damnsterFactoryAddr;

    ///@dev amountOut. not amountIn.
    struct DevInputInfo {
        address tokenIn;
        uint256 amountOut; 
    }

    constructor(
        address _damnsterFactoryAddr
    ) Ownable(msg.sender) {
        damnsterFactoryAddr = _damnsterFactoryAddr;
    }

    function updateDamnsterFactoryAddr(address _damnsterFactoryAddr) external onlyOwner {
        damnsterFactoryAddr = _damnsterFactoryAddr;
    }

    function fromLast20Bytes(
        bytes32 bytesValue
    ) internal pure returns (address) {
        return address(uint160(uint256(bytesValue)));
    }

    function fillLast12Bytes(
        address addressValue
    ) internal pure returns (bytes32) {
        return bytes32(bytes20(addressValue));
    }

    function predictToken(
        address deployer,
        string memory name,
        string memory symbol,
        uint256 supply,
        uint256 fid,
        string memory image,
        string memory castHash,
        bytes32 salt,
        address fromCtrt
    ) public pure returns (address) {
        bytes32 create2Salt = keccak256(abi.encode(deployer, salt));
        
        return fromLast20Bytes(
            keccak256(
                abi.encodePacked(
                    bytes1(0xFF),
                    address(fromCtrt),
                    create2Salt,
                    keccak256(
                        abi.encodePacked(
                            type(DamnsterToken).creationCode,
                            abi.encode(name, symbol, supply, deployer, fid, image, castHash)
                        )
                    )
                )
            )
        );
    }

    function generateSalt(
        address deployer,
        string memory name,
        string memory symbol,
        uint256 supply,
        uint256 fid,
        string memory image,
        string memory castHash
    ) public view returns (bytes32 salt, address token) {
        for (uint256 i; ; i++) {
            salt = bytes32(i);
            token = predictToken(deployer, name, symbol, supply, fid, image, castHash, salt, damnsterFactoryAddr);
            if (token < WETH && token.code.length == 0) {
                break;
            }
        }
    }

    function generateSaltInside(
        address deployer,
        string memory name,
        string memory symbol,
        uint256 supply,
        uint256 fid,
        string memory image,
        string memory castHash
    ) internal view returns (bytes32 salt, address token) {
        for (uint256 i; ; i++) {
            salt = bytes32(i);
            token = predictToken(deployer, name, symbol, supply, fid, image, castHash, salt, address(this));
            if (token < WETH && token.code.length == 0) {
                break;
            }
        }
    }

    function maxUsableTick(int24 tickSpacing) public pure returns (int24) {
        unchecked {
            return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        }
    }

    function simulDevSwap(
        string calldata _name,
        string calldata _symbol,
        uint256 _supply,
        int24 _initialTick,
        uint24 _fee,
        bytes32 _salt,
        address _deployer,
        uint256 _fid,
        string memory _image,
        string memory _castHash,
        DevInputInfo memory devInputInfo
    ) public returns(uint256 amountIn) {
        int24 tickSpacing = IUniswapV3Factory(uniswapV3Factory).feeAmountTickSpacing(_fee);

        require(
            tickSpacing != 0 && _initialTick % tickSpacing == 0,
            "Invalid tick"
        );

        (_salt, ) = generateSaltInside(
            _deployer,
            _name,
            _symbol,
            _supply,
            _fid,
            _image,
            _castHash
        );

        DamnsterToken token = new DamnsterToken{salt: keccak256(abi.encode(_deployer, _salt))}(
            _name,
            _symbol,
            _supply,
            _deployer,
            _fid,
            _image,
            _castHash
        );

        require(address(token) < WETH, "Invalid salt");

        uint160 sqrtPriceX96 = _initialTick.getSqrtRatioAtTick();
        address pool = IUniswapV3Factory(uniswapV3Factory).createPool(address(token), WETH, _fee);
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        MintParams memory mintParams = MintParams(
                address(token),
                WETH,
                _fee,
                _initialTick,
                maxUsableTick(tickSpacing),
                _supply,
                0,
                0,
                0,
                address(this),
                block.timestamp
            );

        token.approve(positionManager, _supply);
        INonfungiblePositionManager(positionManager).mint(mintParams);

        uint256 devAmount = devInputInfo.amountOut;
        if(devAmount > 0) {
            bytes memory path;
            if(devInputInfo.tokenIn == WETH) {
                path = abi.encodePacked(address(token), uint24(_fee), WETH);
            } 
            else {
                path = abi.encodePacked(address(token), uint24(_fee), WETH, uint24(3000), devInputInfo.tokenIn);
            }

            (amountIn, , , ) = IQuoterV2(quoterV2).quoteExactOutput(path, devInputInfo.amountOut);

            IDamnsterFactory damnsterFactory = IDamnsterFactory(damnsterFactoryAddr);
            if(damnsterFactory.bundleFeeSwitch()) {
                amountIn = (amountIn * 1000) / (1000 - damnsterFactory.taxRate());
            }
        }
    }
}