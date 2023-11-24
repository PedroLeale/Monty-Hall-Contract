// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MontyCommit.sol";

contract MontyHall {
    enum MontyHallStep {
        Bet,
        Reveal,
        Change,
        FinalReveal,
        Done
    }

    address payable interviewer;
    address payable player;
    SimpleCommit.CommitType[] doors;
    uint selectedDoor = 0;

    MontyHallStep currentStep;

    uint prize;
    uint collateral;
    uint openDoor;
    uint startingStepTime;
    uint timeLimit;

    event EverythingRevelead();
    event PlayerWon();
    event InterviewWon();

    constructor(
        bytes32 door0,
        bytes32 door1,
        bytes32 door2,
        uint _collateral,
        uint _timeLimit
    ) payable {
        doors.push(
            SimpleCommit.CommitType(
                door0,
                0,
                false,
                SimpleCommit.CommitStatesType.Waiting
            )
        );
        doors.push(
            SimpleCommit.CommitType(
                door1,
                0,
                false,
                SimpleCommit.CommitStatesType.Waiting
            )
        );
        doors.push(
            SimpleCommit.CommitType(
                door2,
                0,
                false,
                SimpleCommit.CommitStatesType.Waiting
            )
        );
        SimpleCommit.commit(doors[0], door0);
        SimpleCommit.commit(doors[1], door1);
        SimpleCommit.commit(doors[2], door2);
        interviewer = payable(msg.sender);
        currentStep = MontyHallStep.Bet;
        prize = msg.value;
        collateral = _collateral;
        startingStepTime = block.timestamp;
        timeLimit = _timeLimit;
    }

    modifier onlyInterviewer() {
        require(msg.sender == interviewer, "Wait your step!");
        _;
    }

    modifier onlyPlayer() {
        require(msg.sender == player, "Wait your step!");
        _;
    }

    function bet(uint door) public payable {
        require(door >= 0 && door <= 2, "Door Range 0, 1 and 2");
        require(
            currentStep == MontyHallStep.Bet,
            "Should be in betting state!"
        );
        require(
            player == address(0x0) || player == msg.sender,
            "Already have a player!"
        );
        require(msg.value >= collateral, "Should transfer collateral");

        player = payable(msg.sender);
        selectedDoor = door;

        currentStep = MontyHallStep.Reveal;
        startingStepTime = block.timestamp;
    }

    function getValue(uint door) public view returns (uint8) {
        return SimpleCommit.getValue(doors[door]);
    }

    function isDoorPrizeable(uint door) public view returns (bool) {
        return getValue(door) == 1;
    }

    function reveal(
        uint door,
        bytes32 nonce,
        uint8 v
    ) public onlyInterviewer returns (bool) {
        require(
            currentStep == MontyHallStep.Reveal,
            "Should be in the first reveal state"
        );
        SimpleCommit.reveal(doors[door], nonce, v);
        if (!SimpleCommit.isCorrect(doors[door]) || isDoorPrizeable(door)) {
            player.transfer(prize);
            currentStep = MontyHallStep.Done;
            return false;
        }
        currentStep = MontyHallStep.Change;
        openDoor = door;
        startingStepTime = block.timestamp;
        return true;
    }

    function change(uint door) public onlyPlayer {
        require(currentStep == MontyHallStep.Change, "Must be in change step");
        require(door >= 0 && door <= 2, "Door Range 0, 1 and 2");
        require(door != openDoor, "This is the Open Door");
        selectedDoor = door;
        currentStep = MontyHallStep.FinalReveal;
        startingStepTime = block.timestamp;
    }

    function isEverythingRevelead() public view returns (bool) {
        bool everythingRevelead = true;
        for (uint8 i = 0; i < 3; i++) {
            everythingRevelead =
                everythingRevelead &&
                SimpleCommit.isRevealed(doors[i]);
        }
        return everythingRevelead;
    }

    function finalReveal(
        uint door,
        bytes32 nonce,
        uint8 v
    ) public onlyInterviewer {
        require(
            currentStep == MontyHallStep.FinalReveal,
            "Should be in final reveal step"
        );

        SimpleCommit.reveal(doors[door], nonce, v);

        if (isEverythingRevelead()) {
            emit EverythingRevelead();
            bool atLeastOneIsPrizeable = false;
            for (uint8 i = 0; i < 3; i++) {
                atLeastOneIsPrizeable =
                    atLeastOneIsPrizeable ||
                    isDoorPrizeable(i);
            }
            if (atLeastOneIsPrizeable && !isDoorPrizeable(selectedDoor)) {
                currentStep = MontyHallStep.Done;
                player.send(collateral);
                interviewer.send(prize);
                emit InterviewWon();
                return;
            }
            currentStep = MontyHallStep.Done;
            player.send(prize + collateral);
            emit PlayerWon();
        }
    }

    function reclaimTimeLimit() public {
        require(msg.sender == interviewer || msg.sender == player);
        require(
            block.timestamp - startingStepTime > timeLimit,
            "Wait until time Limit is reached"
        );
        require(MontyHallStep.Done != currentStep, "Already ended");
        if (msg.sender == interviewer) {
            interviewer.transfer(collateral + prize);
            return;
        }
        player.transfer(collateral + prize);
    }
}
