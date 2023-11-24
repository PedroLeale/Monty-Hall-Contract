// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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
  SimpleCommit[] doors;
  uint selectedDoor = 0;

  MontyHallStep currentStep;

  uint prize;
  uint collateral;
  uint openDoor;

  constructor(SimpleCommit door0, SimpleCommit door1, SimpleCommit door2, uint _collateral) payable {
    doors[0] = door0;
    doors[1] = door1;
    doors[2] = door2;
    interviewer = msg.sender;
    currentStep = MontyHallStep.Bet;
    prize = msg.value;
    collateral = _collateral;
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
    require(currentStep == MontyHallStep.Bet, "Should be in betting state!");
    require(player == address(0x0) || player == msg.sender, "Already have a player!");
    require(msg.value >= collateral, "Should transfer collateral");

    player = msg.sender;
    selectedDoor = door;

    currentStep = MontyHallStep.Reveal;
  }

  function getValue(uint door) public view uint8 {
    return doors[door].getValue();
  }

  function isDoorPrizeable(uint door) public view bool {
    return doors[door].getValue() == uint8(1);
  }

  function reveal(uint door, bytes32 nonce, uint8 v) public onlyInterviewer bool {
    require(currentStep == MontyHallStep.Reveal, "Should be in the first reveal state");
    doors[door].reveal(nonce, v);
    if (!doors[door].isCorrect() || isDoorPrizeable(door)) {
      player.send(prize);
      currentStep = MontyHallStep.Done;
      return false;
    }
    currentStep = MontyHallStep.Change;
    openDoor = door;
  }

  function change(uint door) public onlyPlayer {
    require(currentStep == MontyHallStep.Change, "Must be in change step");
    require(door >= 0 && door <= 2, "Door Range 0, 1 and 2");
    require(door != openDoor, "This is the Open Door");
    selectedDoor = door;
    currentStep = MontyHallStep.FinalReview;
  }

  function isEverythingRevelead() public view bool {
    bool everythingRevelead = false;
    for (uint8 i = 0; i < 3; i++) {
      everythingRevelead = everythingRevelead && doors[i].isCorrect();
    }
    return everythingRevelead;
  }

  function finalReveal(uint door, bytes32 nonce, uint8 v) public onlyInterviewer {
    require(currentStep == MontyHallStep.FinalReveal, "Should be in final reveal state");

    doors[door].reveal(nonce, v);

    if (isEverythingRevelead()) {
      bool atLeastOneIsPrizeable = false;
      for (uint8 i = 0; i < 3; i++) {
        atLeastOneIsPrizeable = atLeastOneIsPrizeable || isDoorPrizeable(i);
      }
      if (atLeastOneIsPrizeable && !isDoorPrizeable(door)) {
        currentStep = MontyHallStep.Done;
        interviewer.send(prize);
        player.send(collateral);
        return;
      }
      currentStep = MontyHallStep.Done;
      player.send(prize+collateral);
    }
  }
}
