// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MontyCommit.sol";

contract MontyHall {
    enum MontyHallStep {
        Bet, // player deve apostar em porta
        Reveal, // entrevistador revela
        Change, // player pode mudar
        FinalReveal, // entrevistador tem de revelar todas outras portas
        Done // finalizado
    }

    address payable interviewer;
    address payable player;
    SimpleCommit.CommitType[] doors; // array de commits -> hash das portas
    uint selectedDoor = 0; // porta do player

    MontyHallStep currentStep;

    uint prize;
    uint collateral;
    uint openDoor; // porta que foi aberta
    uint startingStepTime; // tempo inicial da CURRENTSTEP
    uint timeLimit; // tempo limite de cada *ETAPA*

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

        // como o interviewer ja passou o premio pro contrato, ele nao paga collateral, mas deve indicar quanto eh
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
        require(door >= 0 && door <= 2, "Door Range 0, 1 and 2"); // porta valida
        require(
            currentStep == MontyHallStep.Bet, // estado de aposta
            "Should be in betting state!"
        );
        require(
            player == address(0x0) || player == msg.sender, // player deve estar resetado/ser ele mesmo
            "Already have a player!"
        );
        require(msg.value >= collateral, "Should transfer collateral"); // deve pagar collateral

        // seta o player e aposta
        player = payable(msg.sender);
        selectedDoor = door;

        currentStep = MontyHallStep.Reveal; // avanca
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
        SimpleCommit.reveal(doors[door], nonce, v); // revelar
        if (!SimpleCommit.isCorrect(doors[door]) || isDoorPrizeable(door)) {
            // se revelar falso, cheatou, paga o player para puni-lo
            player.transfer(prize);
            currentStep = MontyHallStep.Done;
            return false;
        }
        currentStep = MontyHallStep.Change; // avanca para escolha do player
        openDoor = door;
        startingStepTime = block.timestamp;
        return true;
    }

    function change(uint door) public onlyPlayer {
        require(currentStep == MontyHallStep.Change, "Must be in change step");
        require(door >= 0 && door <= 2, "Door Range 0, 1 and 2"); // door valida
        require(door != openDoor, "This is the Open Door"); // nao pode tentar colocar na porta aberta...
        selectedDoor = door; // escolhe a que ele pedir (mesmo que seja a mesma)
        currentStep = MontyHallStep.FinalReveal; // avanca...
        startingStepTime = block.timestamp;
    }

    function isEverythingRevelead() public view returns (bool) {
        bool everythingRevelead = true;
        // verificar se todos estão revelados
        for (uint8 i = 0; i < 3; i++) {
            everythingRevelead =
                everythingRevelead &&
                SimpleCommit.isRevealed(doors[i]);
        }
        return everythingRevelead;
    }

    // entrevistador revela UMA A UMA
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
        if (!SimpleCommit.isCorrect(doors[door])) {
            // se revelar falso, deve punir entrevistador
            player.transfer(prize + collateral);
            currentStep = MontyHallStep.Done;
            return;
        }

        // caso sseja ultimo reveal faltante
        if (isEverythingRevelead()) {
            emit EverythingRevelead();
            bool atLeastOneIsPrizeable = false;
            // verificar que pelo menos um premio foi verdadeiro, se nao eh sacanagem com jogador...
            for (uint8 i = 0; i < 3; i++) {
                atLeastOneIsPrizeable =
                    atLeastOneIsPrizeable ||
                    isDoorPrizeable(i);
            }
            // caso onde entrevistador foi honesto e jogador errou
            if (atLeastOneIsPrizeable && !isDoorPrizeable(selectedDoor)) {
                currentStep = MontyHallStep.Done; // acabar
                player.send(collateral); // devolver collateral porque foi honesto
                interviewer.send(prize); // pagar entrevistador
                emit InterviewWon();
                return;
            }
            currentStep = MontyHallStep.Done; // senao... acabar e devolver collateral + premio
            player.send(prize + collateral);
            emit PlayerWon();
        }
    }

    /**
     * Permitir reclamar apenas:
     * * Caso tenha ultrapassado tempo limite
     * * Seja parte envolvida
     * * Devolver de acordo COM O ESTADO ATUAL (ja que apenas um deve agir por estado...)
     */
    function reclaimTimeLimit() public {
        require(msg.sender == interviewer || msg.sender == player);
        require(
            block.timestamp - startingStepTime > timeLimit,
            "Wait until time Limit is reached"
        );
        require(MontyHallStep.Done != currentStep, "Already ended");
        if (currentStep == MontyHallStep.Bet) {
            interviewer.send(collateral + prize);
            return;
        }
        if (currentStep == MontyHallStep.Reveal) {
            player.send(collateral + prize);
            return;
        }
        if (currentStep == MontyHallStep.Change) {
            interviewer.send(collateral + prize);
            return;
        }
        if (currentStep == MontyHallStep.FinalReveal) {
            player.send(collateral + prize);
            return;
        }
    }
}
