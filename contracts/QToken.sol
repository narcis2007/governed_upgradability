pragma solidity ^0.4.25;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "zos-lib/contracts/Initializable.sol";

contract QToken is Initializable, ERC20Detailed, ERC20Burnable, ERC20Mintable {

    function initialize(string name, uint initialAmount) public initializer {
        ERC20Detailed.initialize(name, name, 8);
        ERC20Mintable.initialize(msg.sender);
        _mint(msg.sender, initialAmount);
    }
}
