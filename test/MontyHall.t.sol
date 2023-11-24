// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MontyHall.sol";
import "../src/MontyCommit.sol";

contract MontyTest is Test {
    MontyHall monty;
    SimpleCommit.CommitType[] doors;
    uint256 prize = 50 ether;
    uint256 collateral = 20 ether;
    bytes32 defaultNonce = sha256(abi.encodePacked("DefaultNonce"));
    address interviewer = address(0x1);
    address player = address(0x2);

    function setUp() public {
        vm.deal(interviewer, 100 ether);
        vm.deal(player, 100 ether);
        bytes32 door0 = sha256(abi.encodePacked(defaultNonce, uint8(0)));
        bytes32 door1 = sha256(abi.encodePacked(defaultNonce, uint8(1)));
        bytes32 door2 = sha256(abi.encodePacked(defaultNonce, uint8(0)));
        vm.prank(interviewer);
        monty = new MontyHall{value: prize}(door0, door1, door2, collateral, 59 seconds);
    }

    function testPlayerWin() public {
        uint256 playerBalance_Before = player.balance;
        // Player bets on door 0 
        vm.prank(player);
        monty.bet{value: collateral}(0);

        // Interviewer reveals door 2
        vm.prank(interviewer);
        monty.reveal(2, defaultNonce, 0);

        // Player changes to door 1
        vm.prank(player);
        monty.change(1);

        assertEq(address(monty).balance, prize + collateral);

        // Final reveal
        vm.prank(interviewer);
        monty.finalReveal(0, defaultNonce, 0);
        vm.prank(interviewer);
        monty.finalReveal(1, defaultNonce, 1);

        assertGe(player.balance, playerBalance_Before);
    }

    function testPlayerLoose() public {
        uint256 playerBalance_Before = player.balance;
        uint256 interviewerBalance_Before = interviewer.balance;
        // Player bets on door 0 
        vm.prank(player);
        monty.bet{value: collateral}(0);

        // Interviewer reveals door 2
        vm.prank(interviewer);
        monty.reveal(2, defaultNonce, 0);

        // Player won't change
        vm.prank(player);
        monty.change(0);

        assertEq(address(monty).balance, prize + collateral);
        // Final reveal
        vm.prank(interviewer);
        monty.finalReveal(0, defaultNonce, 0);
        vm.prank(interviewer);
        monty.finalReveal(1, defaultNonce, 1);

        assertEq(interviewer.balance, interviewerBalance_Before);
        assertGe(playerBalance_Before, player.balance);
    }

    function testPlayerCheatCase() public {
        vm.warp(0 seconds);
        uint256 playerBalance_Before = player.balance;
        uint256 interviewerBalance_Before = interviewer.balance;
        // Player tries to cheat on bet 
        vm.startPrank(player);

        vm.expectRevert();
        monty.reclaimTimeLimit();

        vm.expectRevert();
        monty.bet{value: collateral}(5555);
        vm.expectRevert();
        monty.bet{value: collateral/2}(5555);

        // Plays normally so we can test the time limitations
        monty.bet{value: collateral}(0);

        vm.expectRevert();
        monty.reclaimTimeLimit();
        vm.stopPrank();

        // Interviewer reveals door 2
        vm.prank(interviewer);
        monty.reveal(2, defaultNonce, 0);

        // Player tries to cheat on change
        vm.startPrank(player);

        vm.expectRevert();
        monty.change(2);
        
        vm.expectRevert();
        monty.change(3);

        // Plays normally
        monty.change(0);
        
        vm.stopPrank();

        assertEq(address(monty).balance, prize + collateral);

        // Final reveal
        vm.prank(interviewer);
        monty.finalReveal(1, defaultNonce, 1);

        vm.expectRevert();
        vm.prank(player);
        monty.change(1);

        vm.prank(interviewer);
        monty.finalReveal(0, defaultNonce, 0);

        assertEq(interviewer.balance, interviewerBalance_Before);
        assertGe(playerBalance_Before, player.balance);
        
        // Tries to cheat post game
        vm.warp(2 days);
        vm.prank(player);
        vm.expectRevert();
        monty.reclaimTimeLimit();
    }

    function testInterviewerCheatsOnDoors() public {
        vm.deal(interviewer, 100 ether);
        vm.deal(player, 100 ether);
        bytes32 door0 = sha256(abi.encodePacked(defaultNonce, uint8(0)));
        bytes32 door1 = sha256(abi.encodePacked(defaultNonce, uint8(0)));
        bytes32 door2 = sha256(abi.encodePacked(defaultNonce, uint8(0)));
        vm.prank(interviewer);
        MontyHall montyCheat = new MontyHall{value: prize}(door0, door1, door2, collateral, 59 seconds);

        uint256 playerBalance_Before = player.balance;
        uint256 interviewerBalance_Before = interviewer.balance;
        // Player bets on door 0 
        vm.prank(player);
        montyCheat.bet{value: collateral}(0);

        // Interviewer reveals door 2
        vm.prank(interviewer);
        montyCheat.reveal(2, defaultNonce, 0);

        // Player changes to door 1
        vm.prank(player);
        montyCheat.change(1);

        assertEq(address(montyCheat).balance, prize + collateral);

        // Final reveal
        vm.prank(interviewer);
        montyCheat.finalReveal(0, defaultNonce, 0);
        vm.prank(interviewer);
        montyCheat.finalReveal(1, defaultNonce, 0);

        assertGe(player.balance, playerBalance_Before);
        assertLe(interviewer.balance, interviewerBalance_Before);
    }

    function testInterviewerCheats() public {
        vm.warp(0 seconds);
        uint256 playerBalance_Before = player.balance;
        uint256 interviewerBalance_Before = interviewer.balance;
        // Player bets on door 0 
        vm.prank(player);
        monty.bet{value: collateral}(0);

        // Interviewer reveals door 2
        vm.startPrank(interviewer);
        monty.reveal(2, defaultNonce, 0); 

        vm.expectRevert();
        monty.reclaimTimeLimit();

        // Player changes to door 1
        vm.prank(player);
        monty.change(1);

        vm.prank(interviewer);
        vm.expectRevert();
        monty.reveal(1, defaultNonce, 1);

        assertEq(address(monty).balance, prize + collateral);

        // Final reveal
        vm.startPrank(interviewer);
        monty.finalReveal(0, defaultNonce, 0);
        vm.expectRevert();
        monty.finalReveal(2, defaultNonce, 0);

        monty.finalReveal(1, defaultNonce, 0); // Game ends here
                                            // when interviewer tries to reveal with the wrong value
        vm.expectRevert();
        monty.finalReveal(1, defaultNonce, 1);
        vm.stopPrank();

        assertGe(player.balance, playerBalance_Before);
        assertLe(interviewer.balance, interviewerBalance_Before);

        // Tries to cheat post game
        vm.warp(2 days);
        vm.prank(interviewer);
        vm.expectRevert();
        monty.reclaimTimeLimit();
    }

    function testReclaimsAfterBet() public {
        vm.warp(0 seconds);
        vm.prank(player);
        monty.bet{value: collateral}(0);
        vm.warp(1 days);
        vm.prank(player);
        monty.reclaimTimeLimit();
    }

    function testReclaimsAfterReveal() public {
        vm.warp(0 seconds);
        vm.prank(player);
        monty.bet{value: collateral}(0);
        vm.prank(interviewer);
        monty.reveal(2, defaultNonce, 0);
        vm.warp(1 days);
        vm.prank(player);
        monty.reclaimTimeLimit();
    }

    function testReclaimsAfterChange() public {
        vm.warp(0 seconds);
        vm.prank(player);
        monty.bet{value: collateral}(0);
        vm.prank(interviewer);
        monty.reveal(2, defaultNonce, 0);
        vm.prank(player);
        monty.change(1);
        vm.warp(1 days);
        vm.prank(player);
        monty.reclaimTimeLimit();
    }

}
