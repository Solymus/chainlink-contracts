// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* 

    This Contract is deployed on Goerli Test Network

    Address: 0x99444b9d9eF74668A165b6EB1D3F18a19fcf040B
    
    To mint dummy USD token, call mint() with some value
    https://goerli.etherscan.io/address/0x99444b9d9ef74668a165b6eb1d3f18a19fcf040b

*/

contract DummyUSD is ERC20 {

    using SafeERC20 for IERC20;

    constructor() ERC20("Dummy USD", "DUSD") { }

    function mint() public payable {
        _mint(msg.sender, 100000 * msg.value);
    }

    function withdraw(uint256 _amount ) public {
        require(_amount <= balanceOf(msg.sender), "Not enough to withdraw");
        require(_amount > 0, "Non zero amount required");
        (bool sent, /* bytes memory data */ ) = payable(msg.sender).call{ value: _amount / 100000}("");
        require(sent, "Failed to send Ether");
        _burn(msg.sender, _amount);
    }

}
