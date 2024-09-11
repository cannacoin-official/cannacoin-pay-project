// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CannacoinPAY is ERC20, Ownable, ReentrancyGuard {

    uint256 public constant MAX_SUPPLY = 42_000_000_000 * 10 ** 18;  // 42 Billion PAY
    uint256 public constant MAX_PURCHASE_LIMIT = 100_000_000 * 10 ** 18;  // 100 million PAY
    uint256 public cooldownPeriod = 1 days;  // Cooldown period (can be updated by owner)
    uint256 public constant USDT_DECIMALS = 10 ** 6; // USDT has 6 decimal places
    uint256 public taxRate = 690; // 6.9% tax rate, scaled by 10000 for precision
    uint256 public stakingPenaltyRate = 500;  // 5% penalty for early withdrawal
    uint256 public minimumStakeDuration = 180 days;  // Minimum staking duration

    IERC20 public usdtContract;  // USDT token contract

    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public lastPurchaseTime;  // Tracks the time of the last purchase
    mapping(address => uint256) public lastTxTime;        // Tracks the time of the last transaction
    mapping(address => uint256) public whitelistExpiry;   // Tracks whitelist expiration times
    mapping(address => uint256) public lastActivityTime;  // Tracks governance or activity time
    mapping(address => bool) public isBlacklisted;        // Blacklist for malicious addresses
    mapping(address => Stake) public stakes;              // Tracks user staking information

    address public liquidityWallet;
    address public crowdfundingWallet;
    address public teamWallet;
    address public advisorWallet;
    address public investorWallet;
    address public reserveFundWallet;
    address public communityWallet;
    address public marketingWallet;
    address public legalWallet;

    struct Stake {
        uint256 amount;      // Amount of staked tokens
        uint256 startTime;   // Timestamp when staking started
        uint256 lastClaimed; // Timestamp when last governance action was claimed
        bool hasClaimedDiscount; // If user has claimed discounted fees
        bool hasAccess;      // If user has gained priority access
    }

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TaxRateUpdated(uint256 newRate);
    event UserWhitelisted(address indexed user);
    event TokensVested(address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, bool early);
    event ClaimedGovernanceRights(address indexed user);
    event ClaimedDiscount(address indexed user);
    event GainedAccess(address indexed user);

    constructor(
        address _usdtAddress,
        address _liquidityWallet,
        address _crowdfundingWallet,
        address _teamWallet,
        address _advisorWallet,
        address _investorWallet,
        address _reserveFundWallet,
        address _communityWallet,
        address _marketingWallet,
        address _legalWallet
    ) ERC20("Cannacoin PAY", "PAY") Ownable(msg.sender) {
        usdtContract = IERC20(_usdtAddress);

        liquidityWallet = _liquidityWallet;
        crowdfundingWallet = _crowdfundingWallet;
        teamWallet = _teamWallet;
        advisorWallet = _advisorWallet;
        investorWallet = _investorWallet;
        reserveFundWallet = _reserveFundWallet;
        communityWallet = _communityWallet;
        marketingWallet = _marketingWallet;
        legalWallet = _legalWallet;

        // Mint initial token allocations
        _mint(liquidityWallet, 420_000_000 * 10 ** 18);
        _mint(crowdfundingWallet, 4_200_000_000 * 10 ** 18);
        _mint(teamWallet, 8_400_000_000 * 10 ** 18);
        _mint(advisorWallet, 2_100_000_000 * 10 ** 18);
        _mint(investorWallet, 6_300_000_000 * 10 ** 18);
        _mint(reserveFundWallet, 6_300_000_000 * 10 ** 18);
        _mint(communityWallet, 8_400_000_000 * 10 ** 18);
        _mint(marketingWallet, 4_200_000_000 * 10 ** 18);
        _mint(legalWallet, 1_680_000_000 * 10 ** 18);
    }

    // ----------- Sliding Tax Scale Mechanism -----------
    function calculateTax(address sender, uint256 amount) public view returns (uint256) {
        uint256 tax = taxRate;

        // Increase tax for frequent traders
        if (block.timestamp - lastTxTime[sender] < 24 hours) {
            tax = 1000; // Increase to 10%
        }

        // Lower tax for long-term holders
        if (block.timestamp - lastPurchaseTime[sender] >= 180 days) {
            tax = 400; // Lower to 4%
        }

        // Increase tax for large transactions
        if (amount > (MAX_SUPPLY / 1000)) { // Example: more than 0.1% of total supply
            tax = 800; // Increase to 8%
        }

        return tax;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 taxAmount = 0;

        if (!isWhitelisted[msg.sender]) {
            uint256 dynamicTaxRate = calculateTax(msg.sender, amount);
            taxAmount = (amount * dynamicTaxRate) / 10000;
        }

        uint256 amountAfterTax = amount - taxAmount;
        _transfer(msg.sender, recipient, amountAfterTax);

        if (taxAmount > 0) {
            _transfer(msg.sender, owner(), taxAmount); // Send tax to owner
        }

        lastTxTime[msg.sender] = block.timestamp;
        return true;
    }

    // ----------- Staking Functionality -----------

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");
        require(transfer(address(this), amount), "Token transfer failed");

        Stake storage stakeData = stakes[msg.sender];

        // Add to the stake if already staked, or create a new stake
        if (stakeData.amount > 0) {
            stakeData.amount += amount;
        } else {
            stakeData.amount = amount;
            stakeData.startTime = block.timestamp;
            stakeData.lastClaimed = block.timestamp;
        }

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount > 0, "No tokens staked");

        uint256 stakedAmount = stakeData.amount;
        bool earlyUnstake = block.timestamp < stakeData.startTime + minimumStakeDuration;

        // Apply early withdrawal penalty if unstaking before the minimum duration
        if (earlyUnstake) {
            uint256 penalty = (stakedAmount * stakingPenaltyRate) / 10000;
            stakedAmount -= penalty;
            transfer(owner(), penalty);
        }

        stakeData.amount = 0;
        transfer(msg.sender, stakedAmount);

        emit Unstaked(msg.sender, stakedAmount, earlyUnstake);
    }

    function claimGovernanceRights() external {
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount > 0, "No tokens staked");
        require(block.timestamp >= stakeData.startTime + minimumStakeDuration, "Minimum staking period not reached");

        stakeData.lastClaimed = block.timestamp;
        emit ClaimedGovernanceRights(msg.sender);
    }

    function claimDiscountedFees() external {
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount > 0, "No tokens staked");
        require(block.timestamp >= stakeData.startTime + 90 days, "Stake 90 days to claim discounted fees");
        require(!stakeData.hasClaimedDiscount, "Discount already claimed");

        stakeData.hasClaimedDiscount = true;
        emit ClaimedDiscount(msg.sender);
    }

    function gainPriorityAccess() external {
        Stake storage stakeData = stakes[msg.sender];
        require(stakeData.amount > 0, "No tokens staked");
        require(block.timestamp >= stakeData.startTime + 30 days, "Stake 30 days to gain access");
        require(!stakeData.hasAccess, "Access already granted");

        stakeData.hasAccess = true;
        emit GainedAccess(msg.sender);
    }

    // ----------- Buy Tokens (ICO) -----------
    function buyTokens(uint256 amountInUSDT) external nonReentrant {
        require(amountInUSDT > 0, "Must send USDT to buy tokens");

        uint256 tokensToMint = amountInUSDT * 1000 * 10 ** 12;  // Adjust for USDT's 6 decimals
        require(tokensToMint <= MAX_PURCHASE_LIMIT, "Exceeds maximum allowed amount");
        require(block.timestamp >= lastPurchaseTime[msg.sender] + cooldownPeriod, "Cooldown period active");
        require(usdtContract.allowance(msg.sender, address(this)) >= amountInUSDT, "USDT allowance too low");

        bool success = usdtContract.transferFrom(msg.sender, address(this), amountInUSDT);
        require(success, "USDT transfer failed");

        _mint(msg.sender, tokensToMint);
        lastPurchaseTime[msg.sender] = block.timestamp;

        if (tokensToMint == MAX_PURCHASE_LIMIT) {
            isWhitelisted[msg.sender] = true;
            emit UserWhitelisted(msg.sender);
        }

        emit TokensPurchased(msg.sender, tokensToMint);
    }

    // ----------- Anti-Gray Trading and Blacklist Mechanism -----------
    mapping(address => uint256) public userTxCount;  // Tracks transaction count per day

    function transferWithLimits(address recipient, uint256 amount) public returns (bool) {
        require(!isBlacklisted[msg.sender], "Address is blacklisted");

        if (block.timestamp - lastTxTime[msg.sender] < 24 hours) {
            require(userTxCount[msg.sender] < 5, "Exceeded daily transaction limit");
            userTxCount[msg.sender] += 1;
        } else {
            userTxCount[msg.sender] = 1;  // Reset daily count after 24 hours
        }

        return super.transfer(recipient, amount);
    }

    function blacklistAddress(address _user) external onlyOwner {
        isBlacklisted[_user] = true;
    }

    function removeBlacklistAddress(address _user) external onlyOwner {
        isBlacklisted[_user] = false;
    }

    // ----------- Vesting Schedule for Team, Advisors, and Investors -----------
    struct VestingSchedule {
        uint256 cliff;  // Cliff period in seconds
        uint256 duration;  // Total vesting duration
        uint256 startTime;  // Vesting start time
        uint256 amount;  // Total amount vested
        uint256 released;  // Amount already released
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    function setVestingSchedule(address beneficiary, uint256 cliff, uint256 duration, uint256 amount) external onlyOwner {
        vestingSchedules[beneficiary] = VestingSchedule({
            cliff: cliff,
            duration: duration,
            startTime: block.timestamp,
            amount: amount,
            released: 0
        });
    }

    function releaseVestedTokens(address beneficiary) external {
        VestingSchedule storage vesting = vestingSchedules[beneficiary];
        require(block.timestamp >= vesting.startTime + vesting.cliff, "Cliff period not reached");

        uint256 vestedAmount = _calculateVestedAmount(vesting);
        uint256 unreleased = vestedAmount - vesting.released;

        require(unreleased > 0, "No tokens to release");

        vesting.released += unreleased;
        _mint(beneficiary, unreleased);
        emit TokensReleased(beneficiary, unreleased);
    }

    function _calculateVestedAmount(VestingSchedule storage vesting) internal view returns (uint256) {
        if (block.timestamp >= vesting.startTime + vesting.duration) {
            return vesting.amount;
        } else {
            return vesting.amount * (block.timestamp - vesting.startTime) / vesting.duration;
        }
    }

    // ----------- Adjustable Cooldown Period -----------
    function setCooldownPeriod(uint256 newCooldownPeriod) external onlyOwner {
        require(newCooldownPeriod >= 1 hours, "Cooldown too short");
        cooldownPeriod = newCooldownPeriod;
    }
}
