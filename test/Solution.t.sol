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

    function test_Solution() public {

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

        vm.deal(playerTwo, 1 ether);
        vm.startPrank(playerTwo);

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

        // Player two move, player two increases stake to trap the other player
        vm.prank(playerTwo);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 2, col: 2 }), 0);

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 1 ether);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(game.moveNonce, 4);
        assertEq(game.winner, address(0));
        assertEq(uint8(game.board[0][0]), uint8(TicTacToe.Tile.X));
        assertEq(uint8(game.board[1][0]), uint8(TicTacToe.Tile.O));

        vm.prank(playerOne);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 2, col: 1 }), 0);

        vm.prank(playerTwo);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 2, col: 0 }), 0);

        vm.prank(playerOne);
        ticTacToeGame.makeMove(TicTacToe.Move({ row: 1, col: 2 }), 0);

        vm.deal(playerTwo, 1 ether);

        vm.prank(playerTwo);
        ticTacToeGame.makeMove{value: 1 ether}(TicTacToe.Move({ row: 1, col: 0 }), 0);

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 2 ether);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(game.moveNonce, 8);
        assertEq(game.winner, address(0));


        vm.deal(playerOne, 1 ether);

        uint256 playerOneBalBefore = payable(playerOne).balance;

        vm.prank(playerOne);
        ticTacToeGame.makeMove{value: 1 ether}(TicTacToe.Move({ row: 0, col: 2 }), 0);

        uint256 playerOneBalAfter = payable(playerOne).balance;

        // The game didn't take player one's balance
        assertEq(playerOneBalBefore, playerOneBalAfter);

        game = ticTacToeGame.getGame(0);
        assertEq(game.playerOne, playerOne);
        assertEq(game.playerTwo, playerTwo);
        assertEq(game.playerOneStake, 1 ether);
        assertEq(game.playerTwoStake, 2 ether);
        assertEq(game.lastMoveAt, block.timestamp);
        assertEq(game.moveNonce, 8);
        assertEq(game.winner, address(0));


        // It's still player one's turn and the game isn't over since the moveNonce wasn't incremented
        // Player one can't play anywhere as all spots are taken
        vm.startPrank(playerOne);
        for (uint _col; _col < 3; ++_col) {
            for (uint _row; _row < 3; ++_row) {
                vm.expectRevert(TicTacToe.TileTaken.selector);
                ticTacToeGame.makeMove{value: 1 ether}(TicTacToe.Move({ row: _row, col: _col }), 0);
            }
        }

        // Cannot claim settlement as game is not over yet
        vm.expectRevert(TicTacToe.GameNotOver.selector);
        ticTacToeGame.settleGame(0);

        vm.startPrank(playerTwo);

        // Enevitably time must now pass by until the game is stale and player two can claim all of the stake
        vm.expectRevert(TicTacToe.GameStillLive.selector);
        ticTacToeGame.staleGameClaim(0);

        vm.warp(block.timestamp + 1 weeks);

        uint256 playerTwoBalBefore = payable(playerTwo).balance;

        // Now player two can claim the stake from both players
        ticTacToeGame.staleGameClaim(0);

        uint256 playerTwoBalAfter = payable(playerTwo).balance;

        assertEq(playerTwoBalAfter - playerTwoBalBefore, 3 ether);

    }


}