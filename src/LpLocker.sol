// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {INonfungiblePositionManager, CollectParams} from "./interfaces/UniInterface.sol";

contract LpLocker is Ownable, IERC721Receiver {
    event ERC721Released(address indexed token, uint256 amount);
    event LockId(uint256 _id);
    event LockDuration(uint256 _time);
    event Received(address indexed from, uint256 tokenId);
    error NotOwner(address owner);

    event ClaimedFees(
        address indexed claimer,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 totalAmount1,
        uint256 totalAmount0
    );

    uint256 private _released;
    mapping(address => uint256) public _erc721Released;
    IERC721 private SafeERC721;
    uint64 private immutable _duration;
    address private immutable e721Token;
    bool private flag;
    INonfungiblePositionManager private positionManager;
    uint256 public _fee;
    address public _feeRecipient;
    address public _damnsterFactory;

    /**
     * @dev Sets the sender as the initial owner, the beneficiary as the pending owner, and the duration for the lock
     * vesting duration of the vesting wallet.
     */
    constructor(
        address token,
        address damnsterFactory,
        address beneficiary,
        uint64 durationSeconds,
        uint256 fee,
        address feeRecipient
    ) payable Ownable(beneficiary) {
        _duration = durationSeconds;
        SafeERC721 = IERC721(token);
        //already false but lets be safe
        flag = false;
        e721Token = token;
        _fee = fee;
        _feeRecipient = feeRecipient;
        _damnsterFactory = damnsterFactory;
        emit LockDuration(durationSeconds);
    }

    function initializer(uint256 token_id) public {
        require(flag == false, "contract already initialized");
        _erc721Released[e721Token] = token_id;
        flag = true;
        positionManager = INonfungiblePositionManager(e721Token);

        if (positionManager.ownerOf(token_id) != address(this)) {
            SafeERC721.transferFrom(owner(), address(this), token_id);
        }

        emit LockId(token_id);
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return duration();
    }

    /**
     * @dev returns the tokenId of the locked LP
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc721Released[token];
    }

    /**
     * @dev Release the token that have already vested.
     *
     * Emits a {ERC721Released} event.
     */
    function release() public virtual {
        if (vestingSchedule() != 0) {
            revert();
        }
        uint256 id = _erc721Released[e721Token];
        emit ERC721Released(e721Token, id);
        SafeERC721.transferFrom(address(this), owner(), id);
    }

    function withdrawERC20(address _token) public {
        require(owner() == msg.sender, "only owner can call");
        IERC20 IToken = IERC20(_token);
        IToken.transferFrom(address(this), owner(), IToken.balanceOf(owner()));
    }

    //Use collect fees to collect the fees
    function collectFees(address _recipient, uint256 _tokenId) public returns (uint256 recipientFee0, uint256 recipientFee1) {
        if (owner() != msg.sender && owner() != tx.origin && _damnsterFactory != msg.sender) { 
            revert NotOwner(owner());
        }

        if(_damnsterFactory == msg.sender && _recipient != owner()) {
            revert("invalid fee recipient"); 
        }

        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = positionManager.positions(_tokenId);

        (uint256 amount0, uint256 amount1) = positionManager
            .collect(
                CollectParams({
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: _tokenId
                })
            );

        recipientFee0 = amount0;
        recipientFee1 = amount1;

        if (_fee > 0) {
            uint256 protocolFee0 = (amount0 * _fee) / 100;
            uint256 protocolFee1 = (amount1 * _fee) / 100;

            recipientFee0 -= protocolFee0;
            recipientFee1 -= protocolFee1;

            IERC20(token0).transfer(_feeRecipient, protocolFee0);
            IERC20(token1).transfer(_feeRecipient, protocolFee1);
        }

        IERC20(token0).transfer(_recipient, recipientFee0);
        IERC20(token1).transfer(_recipient, recipientFee1);  

        emit ClaimedFees(
            _recipient,
            token0,
            token1,
            recipientFee0,
            recipientFee1,
            amount0,
            amount1
        );
    }

    /**
     * Checks the vesting schedule for the token
     */
    function vestingSchedule() public view returns (uint256) {
        if (block.timestamp > duration()) {
            return 0;
        } else {
            return duration() - block.timestamp;
        }
    }

    function onERC721Received(
        address,
        address from,
        uint256 id,
        bytes calldata data
    ) external override returns (bytes4) {
        emit Received(from, id);

        return IERC721Receiver.onERC721Received.selector;
    }


    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}
}
