pragma solidity ^0.6.6;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
interface IRC {
    /**
     * @notice Returns the rate to pay out for a given amount
     * @param amount the bet amount to calc a payout for
     * @param maxAvailable the total pooled ETH unlocked and available to bet
     * @return profit total possible profit amount
     */
    function rate(uint256 amount, uint256 maxAvailable) external view returns (uint256);

}

contract RateCalc20Percent is IRC {
    using SafeMath for uint256;
     /**
     * @notice Calculates maximum option buyer profit
     * @param amount Option amount
     * @return profit total possible profit amount
     */
    function rate(uint256 amount, uint256 maxAvailable) external view override returns (uint256)  {
        uint256 twentyPercent = maxAvailable.div(5);
        require(amount <= twentyPercent, "greater then pool funds available");
        uint256 oneTenth = amount.div(10);
        uint256 halfMax = twentyPercent.div(2);
        if (amount > halfMax) {
            return amount.mul(2).add(oneTenth).add(oneTenth);
        } else {
            if(oneTenth > 0) {
                return amount.mul(2).sub(oneTenth);
            } else {
                uint256 oneThird = amount.div(4);
                require(oneThird > 0, "invalid bet amount");
                return amount.mul(2).sub(oneThird);
            }
        }
        
    }
}

