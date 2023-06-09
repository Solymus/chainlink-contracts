// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/*

    This Contract is deployed on Goerli Test Network

    Address: 0x0B9A3f7e3b9d34D5C009a74fDDEED09a03CE1cb2

    Solymus proof-of-concept for ChainLink Hackathon 2023

*/

contract SolymusGold is ERC20, Ownable {

    using SafeERC20 for IERC20;

    AggregatorV3Interface internal priceFeed;
    IERC20 internal usdCoin;

    event OrderCreated(address indexed initiator, uint256 orderId);

    enum OrderStatus {
        Pending,
        CanceledByCreator,
        CanceledByOperator,
        InExecution,
        Completed
    }

    struct Order {
        address initiator;
        uint256 spentAmount;
        int price;
        uint256 toReceive;
        uint256 toReturn;
        OrderStatus status;
    }

    mapping(uint256 => Order) internal orders;
    uint256 public latestOrder = 0;
    uint256 internal latestInExecutionOrder = 0;
    uint256 public latestProcessedOrder = 0;

    address internal operator;


    constructor() ERC20("Solymus Gold", "GOLD") {
        // Gold(oz)/USD - goerli, 18 digits
        priceFeed = AggregatorV3Interface(0x7b219F57a8e9C7303204Af681e9fA69d17ef626f);
        // Dummy USD - goerli, 18 digits
        usdCoin = IERC20(0x99444b9d9eF74668A165b6EB1D3F18a19fcf040B);
        // usdCoin = IERC20(0xcD6a42782d230D7c13A74ddec5dD140e55499Df9);
    }

    function getOrder(uint256 _id) public view returns (Order memory) {
        return orders[_id];
    }

    /* Operator account is used to confirm and execute orders and can be different from owner */

    function setOperator(address _operator) onlyOwner public {
        operator = _operator;
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    /**
     * Ensure only operator can execute
     */
    modifier onlyOperator() {
        require(msg.sender == operator, "Not an operator");
        _;
    }

    /* ONLY ACQUIRE ORDERS ACCEPTED DURING TEST */


    /**
     * Request some GOLD to be bought off-chain
     */
    function placeOrder(uint256 _spentAmount) public {

        require(0 < _spentAmount, "Balance should be greater than zero");

        uint256 _amountAllowed = usdCoin.allowance(msg.sender, address(this));
        require(_spentAmount <= _amountAllowed, "Not allowed to spent");

        usdCoin.safeTransferFrom(msg.sender, address(this), _spentAmount);

        Order memory _order = Order(
            msg.sender,
            _spentAmount,
            0,
            0,
            0,
            OrderStatus.Pending
        );

        latestOrder += 1;
        orders[latestOrder] = _order;

    }
    
    function initiateExecution() onlyOperator public {

        require(0 < latestOrder, "No orders yet");


        (
             /*uint80 roundID*/,
             int _price,
             /*uint startedAt*/,
             uint timeStamp,
             /*uint80 _answeredInRound*/
        ) = priceFeed.latestRoundData();

        require(block.timestamp < timeStamp + 3600, "Exceeds one hour");

        // int _price = 7 * 10**18;

        int overheadPrice = (_price * 30 + _price * 1000) / 1000; // Add 3% for transaction comission and slippage

        while (latestInExecutionOrder < latestOrder) {
            latestInExecutionOrder ++;
            orders[latestInExecutionOrder].price = overheadPrice;
            uint256 toReceive = 10**18 * (orders[latestInExecutionOrder].spentAmount / uint(overheadPrice));

            if (toReceive == 0) {
                orders[latestInExecutionOrder].status = OrderStatus.CanceledByOperator;
                // usdCoin.safeTransferFrom(address(this), orders[latestInExecutionOrder].initiator, orders[latestInExecutionOrder].spentAmount);
                require(usdCoin.transfer(orders[latestInExecutionOrder].initiator, orders[latestInExecutionOrder].spentAmount), "Transfer failed");
            } else {
                uint256 toReturn = orders[latestInExecutionOrder].spentAmount - ((toReceive * uint(overheadPrice)) / 10**18);
                orders[latestInExecutionOrder].toReceive = toReceive;
                orders[latestInExecutionOrder].toReturn = toReturn;
                orders[latestInExecutionOrder].status = OrderStatus.InExecution;
                // usdCoin.safeTransferFrom(address(this), orders[latestInExecutionOrder].initiator, toReturn);
                require(usdCoin.transfer(orders[latestInExecutionOrder].initiator, toReturn), "Transfer failed");

            }

        }
    }

    function getNextUncompletedOrder() public view returns (Order memory) {

        require(0 < latestOrder, "No orders yet");

        uint256 _i = latestProcessedOrder;

        while (_i < latestOrder) {
            _i ++;

            if (orders[_i].status == OrderStatus.InExecution) {
                return orders[_i];
            }

        }

        require(false, "No orders yet");
    }

    function markNextOrderCompleted() onlyOperator public {
        while (latestProcessedOrder < latestOrder) {
            latestProcessedOrder ++;
            if (orders[latestProcessedOrder].status == OrderStatus.InExecution) {
                orders[latestProcessedOrder].status = OrderStatus.Completed;
                _mint(orders[latestProcessedOrder].initiator, orders[latestProcessedOrder].toReceive);
                return;
            }
        }
    }

    function markNextOrderCanceled() onlyOperator public {
        while (latestProcessedOrder < latestOrder) {
            latestProcessedOrder ++;
            if (orders[latestProcessedOrder].status == OrderStatus.InExecution) {
                orders[latestProcessedOrder].status = OrderStatus.CanceledByOperator;
                uint256 toReturnBack = (orders[latestProcessedOrder].toReceive * uint(orders[latestProcessedOrder].price)) / 10**18;
                require(usdCoin.transfer(orders[latestProcessedOrder].initiator, toReturnBack), "Transfer failed");
                return;
            }
        }
    }

}
