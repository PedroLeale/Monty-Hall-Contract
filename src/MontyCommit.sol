// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library SimpleCommit {
    enum CommitStatesType {
        Waiting,
        Revealed
    }

    struct CommitType {
        bytes32 commited;
        uint8 value;
        bool verified;
        CommitStatesType myState;
    }

    function commit(CommitType storage c, bytes32 h) public {
        c.commited = h;
        c.verified = false;
        c.myState = CommitStatesType.Waiting;
    }

    function reveal(CommitType storage c, bytes32 nonce, uint8 v) public {
        require(c.myState == CommitStatesType.Waiting);
        bytes32 ver = sha256(abi.encodePacked(nonce, v));
        c.myState = CommitStatesType.Revealed;
        if (ver == c.commited) {
            c.verified = true;
            c.value = v;
        }
    }

    function isRevealed(CommitType storage c) public view returns (bool) {
        return c.verified; // so verificar sem revert
    }

    function isCorrect(CommitType storage c) public view returns (bool) {
        require(c.myState == CommitStatesType.Revealed, "Wait!");
        return c.verified;
    }

    function getValue(CommitType storage c) public view returns (uint8) {
        require(c.myState == CommitStatesType.Revealed);
        require(c.verified == true);
        return c.value;
    }
}
