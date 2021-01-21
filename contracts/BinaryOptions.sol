pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

import "./BIOPToken.sol";
import "./RateCalc.sol";


/**
 * @title Binary Options Eth Pool
 * @author github.com/Shalquiana
 * @dev Pool ETH Tokens and use it for optionss
 * Biop
 */
contract BinaryOptions is ERC20 {
    using SafeMath for uint256;
    address payable devFund;
    address payable owner;
    address public biop;
    address public rcAddress;//address of current rate calculators
    mapping(address=>uint256) public nextWithdraw;
    mapping(address=>bool) public enabledPairs;
    uint256 public minTime;
    uint256 public maxTime;
    address public defaultPair;
    uint256 public lockedAmount;
    uint256 public exerciserFee = 50;//in tenth percent
    uint256 public expirerFee = 50;//in tenth percent
    uint256 public devFundBetFee = 2;//tenth of percent
    uint256 public poolLockSeconds = 2 days;
    uint256 public contractCreated;
    uint256 public launchEnd;
    bool public open = true;
    Option[] public options;
    
    //reward amounts
    uint256 aStakeReward = 120000000000000000000;
    uint256 bStakeReward = 60000000000000000000;
    uint256 betReward = 40000000000000000000;
    uint256 exerciseReward = 2000000000000000000;


    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }


    /* Types */
    enum OptionType {Put, Call}
    enum State {Active, Exercised, Expired}
    struct Option {
        State state;
        address payable holder;
        uint256 strikePrice;
        uint256 purchaseValue;
        uint256 lockedValue;//purchaseAmount+possible reward for correct bet
        uint256 expiration;
        OptionType optionType;
        address priceProvider;
    }

    /* Events */
     event Create(
        uint256 indexed id,
        address payable account,
        uint256 strikePrice,
        uint256 lockedValue,
        OptionType direction
    );
    event Payout(uint256 poolLost, address winner);
    event Exercise(uint256 indexed id);
    event Expire(uint256 indexed id);


    function getMaxAvailable() public view returns(uint256) {
        uint256 balance = address(this).balance;
        if (balance > lockedAmount) {
            return balance.sub(lockedAmount);
        } else {
            return 0;
        }
    }

    constructor(string memory name_, string memory symbol_, address pp_, address biop_, address rateCalc_) public ERC20(name_, symbol_){
        devFund = msg.sender;
        owner = msg.sender;
        biop = biop_;
        rcAddress = rateCalc_;
        lockedAmount = 0;
        contractCreated = block.timestamp;
        launchEnd = block.timestamp+28 days;
        enabledPairs[pp_] = true; //default pair ETH/USD
        defaultPair = pp_;
        minTime = 900;//15 minutes
        maxTime = 60 minutes;
    }

    /**
     * @dev the default price provider. This is a convenience method
     */
    function defaultPriceProvider() public view returns (address) {
        return defaultPair;
    }


     /**
     * @dev add a price provider to the enabledPairs list
     * @param newRC_ the address of the AggregatorV3Interface price provider contract address to add.
     */
    function setRateCalcAddress(address newRC_) external onlyOwner {
        rcAddress = newRC_; 
    }

    /**
     * @dev add a price provider to the enabledPairs list
     * @param newPP_ the address of the AggregatorV3Interface price provider contract address to add.
     */
    function addPP(address newPP_) external onlyOwner {
        enabledPairs[newPP_] = true; 
    }

   

    /**
     * @dev remove a price provider from the enabledPairs list
     * @param oldPP_ the address of the AggregatorV3Interface price provider contract address to remove.
     */
    function removePP(address oldPP_) external onlyOwner {
        enabledPairs[oldPP_] = false;
    }

    /**
     * @dev update the max time for option bets
     * @param newMax_ the new maximum time (in seconds) an option may be created for (inclusive).
     */
    function setMaxTime(uint256 newMax_) external onlyOwner {
        maxTime = newMax_;
    }

    /**
     * @dev update the max time for option bets
     * @param newMin_ the new minimum time (in seconds) an option may be created for (inclusive).
     */
    function setMinTime(uint256 newMin_) external onlyOwner {
        minTime = newMin_;
    }

    /**
     * @dev address of this contract, convenience method
     */
    function thisAddress() public view returns (address){
        return address(this);
    }

    /**
     * @dev set the fee users can recieve for exercising other users options
     * @param exerciserFee_ the new fee (in tenth percent) for exercising a options itm
     */
    function updateExerciserFee(uint256 exerciserFee_) external onlyOwner {
        require(exerciserFee_ > 1 && exerciserFee_ < 500, "invalid fee");
        exerciserFee = exerciserFee_;
    }

     /**
     * @dev set the fee users can recieve for expiring other users options
     * @param expirerFee_ the new fee (in tenth percent) for expiring a options
     */
    function updateExpirerFee(uint256 expirerFee_) external onlyOwner {
        require(expirerFee_ > 1 && expirerFee_ < 50, "invalid fee");
        expirerFee = expirerFee_;
    }

    /**
     * @dev set the fee users pay to buy an option
     * @param devFundBetFee_ the new fee (in tenth percent) to buy an option
     */
    function updateDevFundBetFee(uint256 devFundBetFee_) external onlyOwner {
        require(devFundBetFee_ >= 0 && devFundBetFee_ < 50, "invalid fee");
        devFundBetFee = devFundBetFee_;
    }

     /**
     * @dev update the pool stake lock up time.
     * @param newLockSeconds_ the new lock time, in seconds
     */
    function updatePoolLockSeconds(uint256 newLockSeconds_) external onlyOwner {
        require(newLockSeconds_ >= 0 && newLockSeconds_ < 14 days, "invalid fee");
        poolLockSeconds = newLockSeconds_;
    }

    /**
     * @dev used to transfer ownership
     * @param newOwner_ the address of governance contract which takes over control
     */
    function transferOwner(address payable newOwner_) external onlyOwner {
        owner = newOwner_;
    }

    /**
     * @dev used to transfer devfund 
     * @param newDevFund the address of governance contract which takes over control
     */
    function transferDevFund(address payable newDevFund) external onlyOwner {
        devFund = newDevFund;
    }


     /**
     * @dev used to send this pool into EOL mode when a newer one is open
     */
    function closeStaking() external onlyOwner {
        open = false;
    }

    /**
     * @dev update the amount of early user governance tokens that have been assigned
     * @param amount the amount assigned
     */
    function updateRewards(uint256 amount) internal {
        BIOPToken b = BIOPToken(biop);
        if (b.earlyClaims()) {
            b.updateEarlyClaim(amount.mul(4));
        } else if (b.totalClaimsAvailable() > 0){
            b.updateClaim(amount);
        }
    }


    /**
     * @dev send ETH to the pool. Recieve pETH token representing your claim.
     * If rewards are available recieve BIOP governance tokens as well.
    */
    function stake() external payable {
        require(open == true, "pool deposits has closed");
        require(msg.value >= 100, "stake to small");
        if (block.timestamp < launchEnd) {
            nextWithdraw[msg.sender] = block.timestamp + 14 days;
            _mint(msg.sender, msg.value);
        } else {
            nextWithdraw[msg.sender] = block.timestamp + poolLockSeconds;
            _mint(msg.sender, msg.value);
        }

        if (msg.value >= 2000000000000000000) {
            updateRewards(aStakeReward);
        } else {
            updateRewards(bStakeReward);
        }
    }

    /**
     * @dev recieve ETH from the pool. 
     * If the current time is before your next available withdraw a 1% fee will be applied.
     * @param amount The amount of pETH to send the pool.
    */
    function withdraw(uint256 amount) public {
       require (balanceOf(msg.sender) >= amount, "Insufficent Share Balance");

        uint256 valueToRecieve = amount.mul(address(this).balance).div(totalSupply());
        _burn(msg.sender, amount);
        if (block.timestamp <= nextWithdraw[msg.sender]) {
            //early withdraw fee
            uint256 penalty = valueToRecieve.div(100);
            require(devFund.send(penalty), "transfer failed");
            require(msg.sender.send(valueToRecieve.sub(penalty)), "transfer failed");
        } else {
            require(msg.sender.send(valueToRecieve), "transfer failed");
        }
    }

     /**
    @dev Open a new call or put options.
    @param type_ type of option to buy
    @param pp_ the address of the price provider to use (must be in the list of enabledPairs)
    @param time_ the time until your options expiration (must be minTime < time_ > maxTime)
    */
    function bet(OptionType type_, address pp_, uint256 time_) external payable {
        require(
            type_ == OptionType.Call || type_ == OptionType.Put,
            "Wrong option type"
        );
        require(
            time_ >= minTime && time_ <= maxTime,
            "Invalid time"
        );
        require(msg.value >= 100, "bet to small");
        require(enabledPairs[pp_], "Invalid  price provider");
        uint depositValue;
        if (devFundBetFee > 0) {
            uint256 fee = msg.value.div(devFundBetFee).div(100);
            require(devFund.send(fee), "devFund fee transfer failed");
            depositValue = msg.value.sub(fee);
            
        } else {
            depositValue = msg.value;
        }

        RateCalc rc = RateCalc(rcAddress);
        uint256 lockValue = getMaxAvailable();
        lockValue = rc.rate(depositValue, lockValue.sub(depositValue));
        


         
        AggregatorV3Interface priceProvider = AggregatorV3Interface(pp_);
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        uint256 optionID = options.length;
        uint256 totalLock = lockValue.add(depositValue);
        Option memory op = Option(
            State.Active,
            msg.sender,
            uint256(latestPrice),
            depositValue,
            totalLock,//purchaseAmount+possible reward for correct bet
            block.timestamp + time_,//all options 1hr to start
            type_,
            pp_
        );
        lock(totalLock);
        options.push(op);
        emit Create(optionID, msg.sender, uint256(latestPrice), totalLock, type_);
        updateRewards(betReward);
    }

     /**
     * @notice exercises a option
     * @param optionID id of the option to exercise
     */
    function exercise(uint256 optionID)
        external
    {
        Option memory option = options[optionID];
        require(block.timestamp <= option.expiration, "expiration date margin has passed");
        AggregatorV3Interface priceProvider = AggregatorV3Interface(option.priceProvider);
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        uint256 uLatestPrice = uint256(latestPrice);
        if (option.optionType == OptionType.Call) {
            require(uLatestPrice > option.strikePrice, "price is to low");
        } else {
            require(uLatestPrice < option.strikePrice, "price is to high");
        }

        //option expires ITM, we pay out
        payout(option.lockedValue.sub(option.purchaseValue), msg.sender, option.holder);
        
        lockedAmount = lockedAmount.sub(option.lockedValue);
        emit Exercise(optionID);
        updateRewards(exerciseReward);
    }

     /**
     * @notice expires a option
     * @param optionID id of the option to expire
     */
    function expire(uint256 optionID)
        external
    {
        Option memory option = options[optionID];
        require(block.timestamp > option.expiration, "expiration date has not passed");
        unlock(option.lockedValue.sub(option.purchaseValue), msg.sender, expirerFee);
        emit Expire(optionID);
        lockedAmount = lockedAmount.sub(option.lockedValue);

        updateRewards(exerciseReward);
    }

    /**
    @dev called by BinaryOptions contract to lock pool value coresponding to new binary options bought. 
    @param amount amount in ETH to lock from the pool total.
    */
    function lock(uint256 amount) internal {
        lockedAmount = lockedAmount.add(amount);
    }

    /**
    @dev called by BinaryOptions contract to unlock pool value coresponding to an option expiring otm. 
    @param amount amount in ETH to unlock
    @param goodSamaritan the user paying to unlock these funds, they recieve a fee
    */
    function unlock(uint256 amount, address payable goodSamaritan, uint256 eFee) internal {
        require(amount <= lockedAmount, "insufficent locked pool balance to unlock");
        uint256 fee = amount.div(eFee).div(100);
        if (fee > 0) {
            require(goodSamaritan.send(fee), "good samaritan transfer failed");
        }
    }

    /**
    @dev called by BinaryOptions contract to payout pool value coresponding to binary options expiring itm. 
    @param amount amount in BIOP to unlock
    @param exerciser address calling the exercise/expire function, this may the winner or another user who then earns a fee.
    @param winner address of the winner.
    @notice exerciser fees are subject to change see updateFeePercent above.
    */
    function payout(uint256 amount, address payable exerciser, address payable winner) internal {
        require(amount <= lockedAmount, "insufficent pool balance available to payout");
        require(amount <= address(this).balance, "insufficent balance in pool");
        if (exerciser != winner) {
            //good samaratin fee
            uint256 fee = amount.div(exerciserFee).div(100);
            if (fee > 0) {
                require(exerciser.send(fee), "exerciser transfer failed");
                require(winner.send(amount.sub(fee)), "winner transfer failed");
            }
        } else {  
            require(winner.send(amount), "winner transfer failed");
        }
        emit Payout(amount, winner);
    }

}