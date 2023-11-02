// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MontyToken is ERC20 {
    mapping(address => bool) trustedAddresses;
    address owner;
    bool token_type; // true : car
                     // false: goat
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyTrustedAddresses(address _address) {
        require(trustedAddresses[_address], "Only trusted addresses can call this function.");
        _;
    }

    constructor(bool _token_type) ERC20("MontyToken", "MNT") {
        owner = msg.sender;
        trustedAddresses[msg.sender] = true;
        token_type = _token_type;
    }

}