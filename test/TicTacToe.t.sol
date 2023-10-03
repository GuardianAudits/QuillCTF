// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { TicTacToe } from "../src/TicTacToe.sol";

contract TicTacToeTest is Test {
    TicTacToe public ticTacToeGame;

    address constant playerOne = address(100);
    address constant playerTwo = address(101);

    function setUp() public {
        ticTacToeGame = new TicTacToe();
    }

    function test_Player1Wins() external {
        vm.deal(playerOne, 1 ether);
        vm.prank(playerOne);
        ticTacToeGame.startGame{value: 1 ether}(playerTwo);

        TicTacToe.Game memory game = ticTacToeGame.getGame(0);

        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 0);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(uint8(game.board[0][0]), uint8(TicTacToe.Tile.Empty));

        vm.startPrank(playerOne);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 0, col: 0 }), 0);

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 0);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(uint8(game.board[0][0]), uint8(TicTacToe.Tile.X));
        assertEq(uint8(game.board[0][1]), uint8(TicTacToe.Tile.Empty));

        // Player one cannot move now
        vm.expectRevert(TicTacToe.NotPlayerTwo.selector);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 0, col: 0 }), 0);
        vm.stopPrank();

        vm.deal(playerTwo, 1 ether);
        vm.startPrank(playerTwo);

        // Player two must provide enough stake
        vm.expectRevert(TicTacToe.NotEnoughStake.selector);
        ticTacToeGame.makeMove{ value: 0.9 ether }(TicTacToe.Move({ row: 0, col: 1 }), 0);

        // Player two cannot play on a taken square
        vm.expectRevert(TicTacToe.TileTaken.selector);
        ticTacToeGame.makeMove{ value: 1 ether }(TicTacToe.Move({ row: 0, col: 0 }), 0);

        // Player two moves
        ticTacToeGame.makeMove{ value: 1 ether }(TicTacToe.Move({ row: 0, col: 1 }), 0);

        vm.stopPrank();

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 1 ether);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(game.winner, address(0));
        assertEq(uint8(game.board[0][0]), uint8(TicTacToe.Tile.X));
        assertEq(uint8(game.board[1][0]), uint8(TicTacToe.Tile.O));

        // Player one move
        vm.prank(playerOne);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 1, col: 1 }), 0);

        // Player two move
        vm.prank(playerTwo);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 1, col: 0 }), 0);

        // Player one wins
        vm.prank(playerOne);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 2, col: 2 }), 0);

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 1 ether);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(game.winner, playerOne);
        assertEq(uint8(game.board[0][0]), uint8(TicTacToe.Tile.X));
        assertEq(uint8(game.board[1][0]), uint8(TicTacToe.Tile.O));

        // Player two should not be able to play as the game is over
        vm.startPrank(playerTwo);
        vm.expectRevert(TicTacToe.GameOver.selector);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 2, col: 1 }), 0);
    }
}
