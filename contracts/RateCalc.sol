pragma solidity ^0.6.6;


import "@openzeppelin/contracts/math/SafeMath.sol";
interface IRC {
    /**
     * @notice Returns the rate to pay out for a given amount
     * @param amount the bet amount to calc a payout for
     * @param maxAvailable the total pooled ETH unlocked and available to bet
     * @return profit total possible profit amount
     */
    function rate(uint256 amount, uint256 maxAvailable) external view returns (uint256);

}

contract RateCalc is IRC {
    using SafeMath for uint256;
     /**
     * @notice Calculates maximum option buyer profit
     * @param amount Option amount
     * @return profit total possible profit amount
     */
    function rate(uint256 amount, uint256 maxAvailable) external view override returns (uint256)  {
        require(amount <= maxAvailable, "greater then pool funds available");
        
        uint256 oneTenth = amount.div(10);
        uint256 halfMax = maxAvailable.div(2);
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

