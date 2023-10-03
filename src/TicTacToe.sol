// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract TicTacToe {
    
    error Blacklisted(address blacklistedAddress);
    error WrongMoveNonce(uint256 _moveNonce, uint256 moveNonce);
    error NotPlayerOne();
    error NotPlayerTwo();
    error TileTaken();
    error NotEnoughStake();
    error GameOver();
    error GameNotOver();
    error GameStillLive();

    mapping(uint256 => Game) internal games;
    mapping(address => bool) public blacklist;

    uint256 public gameNonce;
    bytes9 constant public magicSquare = 0x020904070503060108;
    uint256 constant public MIN_STAKE = 1 ether;

    enum Tile {
        Empty,
        X,
        O
    }

    struct Game {
        //   X  Y
        Tile[3][3] board;
        address playerOne;
        address playerTwo;
        uint256 moveNonce;
        address winner;
        uint256 playerOneStake;
        uint256 playerTwoStake;
        uint256 lastMoveAt;
    }

    struct Move {
        uint256 row;
        uint256 col;
    }

    modifier validateGame(address _playerTwo) {
        if (blacklist[msg.sender]) revert Blacklisted(msg.sender);
        if (blacklist[_playerTwo]) revert Blacklisted(_playerTwo);
        require(_playerTwo != address(0));
        require(msg.sender != _playerTwo);
        _;
        ++gameNonce;
    }

    modifier validateMove(Move calldata _move, uint256 _gameId) {
        if (gameOver(_gameId)) revert GameOver();
        if (blacklist[msg.sender]) revert Blacklisted(msg.sender);

        Game memory game = games[_gameId];

        if (game.moveNonce & 1 == 0 && msg.sender != game.playerOne) revert NotPlayerOne();
        if (game.moveNonce & 1 == 1 && msg.sender != game.playerTwo) revert NotPlayerTwo();

        if (msg.value + (game.moveNonce & 1 == 0 ? game.playerOneStake : game.playerTwoStake) < (game.moveNonce & 1 == 0 ? game.playerTwoStake : game.playerOneStake)) {
            revert NotEnoughStake();
        }

        Tile tile = game.board[_move.col][_move.row];
        if (tile != Tile.Empty) revert TileTaken(); 
        _;
        ++games[_gameId].moveNonce;
    }

    function getGame(uint256 _gameId) external view returns (Game memory game) {
        game = games[_gameId];
    }

    function gameOver(uint256 _gameId) public view returns (bool) {
        Game memory game = games[_gameId];

        return game.winner != address(0) || game.moveNonce == 9;
    }

    function settleGame(uint256 _gameId) external {
        if (!gameOver(_gameId)) revert GameNotOver();

        Game memory game = games[_gameId];
        delete games[_gameId];

        bool success;

        if (game.winner != address(0)) {
            uint256 totalStake = game.playerOneStake + game.playerTwoStake;
            (success, ) = payable(game.winner).call{value: totalStake}(""); 
            require(success);
        } else {
            (success, ) = payable(game.playerOne).call{value: game.playerOneStake}(""); 
            require(success);
            (success, ) = payable(game.playerTwo).call{value: game.playerTwoStake}(""); 
            require(success);
        }
    }

    // If one player stops playing the other player may claim all of the stake
    function staleGameClaim(uint256 _gameId) external {
        if(gameOver(_gameId)) revert GameOver();
        Game memory game = games[_gameId];
        if (block.timestamp - game.lastMoveAt < 1 weeks) revert GameStillLive();
        delete games[_gameId];

        bool isPlayerOneTurn = game.moveNonce & 1 == 0;
        require(msg.sender == (isPlayerOneTurn ? game.playerTwo : game.playerOne), "Not correct player");

        uint256 totalStake = game.playerOneStake + game.playerTwoStake;
        (bool success, ) = payable(msg.sender).call{value: totalStake}(""); 
        require(success);
    }

    function startGame(address _playerTwo) external payable validateGame(_playerTwo) {
        require(msg.value >= MIN_STAKE, "lt MIN_STAKE");
        games[gameNonce].playerOne = msg.sender;
        games[gameNonce].playerTwo = _playerTwo;
        games[gameNonce].playerOneStake = msg.value;
        games[gameNonce].lastMoveAt = block.timestamp;
    }

    function makeMove(Move calldata _move, uint256 _gameId) external payable validateMove(_move, _gameId) {
        Game memory game = games[_gameId];

        bool isPlayerOne = game.moveNonce & 1 == 0;
        game.board[_move.col][_move.row] = isPlayerOne ? Tile.X : Tile.O;
        game.lastMoveAt = block.timestamp;

        games[_gameId] = game;

        bytes32 winnerSlot = bytes32(uint256(keccak256(abi.encode(_gameId, 0))) + 6);

        assembly {
            let row0 := mload(0x40)
            let row1 := add(row0, 0x20)
            let row2 := add(row0, 0x40)
            let col0 := add(row0, 0x60)
            let col1 := add(row0, 0x80)
            let col2 := add(row0, 0x100)
            let d0 := add(row0, 0x120)
            let d1 := add(row0, 0x140)
            // We employ the 3x3 magic square to determine the winner
            // https://en.wikipedia.org/wiki/Magic_square
            for { let i := 0 } lt(i, 0x9) { i := add(i, 0x1) } {
                let squareValue := and(shr(sub(0xf8, mul(0x8, i)), magicSquare), 0xff)
                let tile := mload(add(mload(game), add(0x60, mul(i, 0x20))))
                let factor
                switch tile
                case 1 { 
                    factor := 1
                    // playerOneSum := add(playerOneSum, squareValue) 
                    // if eq(playerOneSum, 15) {
                    //     sstore(winnerSlot, mload(add(game, 0x20)))
                    // }
                }
                case 2 { 
                    factor := sub(0, 1)
                    // playerTwoSum := add(playerTwoSum, squareValue)
                    // if eq(playerTwoSum, 15) {
                    //     sstore(winnerSlot, mload(add(game, 0x40)))
                    // }
                }
                default {
                    factor := 0
                }
                if eq(mod(i, 4), 0) { mstore(d0, add(mload(d0), mul(squareValue, factor))) }
                if and(eq(and(i, 0x1), 0), not(iszero(and(i, 0x6)))) { mstore(d1, add(mload(d1), mul(squareValue, factor))) }
                switch mod(i, 3)
                case 0 {
                    mstore(row0, add(mload(row0), mul(squareValue, factor)))
                }
                case 1 {
                    mstore(row1, add(mload(row1), mul(squareValue, factor)))
                }
                case 2 {
                    mstore(row2, add(mload(row2), mul(squareValue, factor)))
                }
                if lt(i, 3) { mstore(col0, add(mload(col0), mul(squareValue, factor))) }
                if and(gt(i, 2), lt(i, 6)) { mstore(col2, add(mload(col2), mul(squareValue, factor))) }
                if gt(i, 5) { mstore(col2, add(mload(col2), mul(squareValue, factor))) }
            }

            for { let i := 0 } lt(i, 0x160) { i := add(i, 0x20) } {
                let value := mload(add(row0, i))
                if and(not(iszero(value)), eq(smod(value, 15), 0)) {
                    switch iszero(and(value, shl(1, 255)))
                    case 0 {
                        sstore(winnerSlot, mload(add(game, 0x20)))
                    }
                    case 1 {
                        sstore(winnerSlot, mload(add(game, 0x40)))
                    }
                }
            }

            // If the player attempts to raise stakes in their last turn, send back the ether and return
            if and(gt(mload(add(game, 0x60)), 7), gt(callvalue(), 0)) {
                if iszero(call(gas(), caller(), callvalue(), 0, 0, 0, 0)) { revert(0, 0) }
                return(0, 0)
            }
        }

        // If stakes are raised, handle that
        if (msg.value > 0) isPlayerOne ? games[_gameId].playerOneStake += msg.value : games[_gameId].playerTwoStake += msg.value;
    }


}