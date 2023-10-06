// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../src/TicTacToe.sol";

contract K is Test {
    TicTacToe tt;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");
        tt = new TicTacToe();
        tt.startGame{value: 1 ether}(alice);
        deal(alice, 10 ether);
    }

    function testEx() public {
        tt.makeMove(TicTacToe.Move(0, 0), 0);
        vm.prank(alice);
        tt.makeMove{value: 1 ether + 1}(TicTacToe.Move(0, 2), 0);

        tt.makeMove{value: 2}(TicTacToe.Move(1, 0), 0);
        vm.prank(alice);
        tt.makeMove{value: 3}(TicTacToe.Move(2, 0), 0);

        tt.makeMove{value: 4}(TicTacToe.Move(0, 1), 0);
        vm.prank(alice);
        tt.makeMove{value: 5}(TicTacToe.Move(1, 1), 0);

        tt.settleGame(0);
        console.log(tt.claimable(address(this)));
        console.log(tt.claimable(alice));
    }

    fallback() external payable {}
}
