pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Coin for voting
contract VotingCoin is ERC20 {
    constructor() ERC20("VotingCoin", "Coin for voting") {
        _mint(msg.sender, 100 * 10 ** 6);
    }
    function decimals() public view override returns (uint8) {
        return 6;
    }
}
