// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import necessary OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Main contract for CannacoinPAY token
contract CannacoinPAY is ERC20, Ownable, ReentrancyGuard {

    uint256 public constant MAX_SUPPLY = 42_000_000_000 * 10 ** 18;  // 42 Billion PAY
    uint256 public constant MAX_PURCHASE_LIMIT = 100_000_000 * 10 ** 18;  // 100 million PAY
    uint256 public constant COOLDOWN_PERIOD = 1 days;  // 24-hour cooldown period

    uint256 public taxRate = 690; // 6.9% tax rate, scaled by 10000 for precision
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public lastPurchaseTime; // Tracks the time of the last purchase

    IERC20 public usdtContract; // USDT token contract

    address public liquidityWallet;
    address public crowdfundingWallet;
    address public teamWallet;
    address public advisorWallet;
    address public investorWallet;
    address public reserveFundWallet;
    address public communityWallet;
    address public marketingWallet;
    address public legalWallet;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TaxRateUpdated(uint256 newRate);
    event UserWhitelisted(address indexed user);

    constructor(
        address _usdtAddress,  // USDT contract address
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
        usdtContract = IERC20(_usdtAddress); // Initialize USDT contract

        liquidityWallet = _liquidityWallet;
        crowdfundingWallet = _crowdfundingWallet;
        teamWallet = _teamWallet;
        advisorWallet = _advisorWallet;
        investorWallet = _investorWallet;
        reserveFundWallet = _reserveFundWallet;
        communityWallet = _communityWallet;
        marketingWallet = _marketingWallet;
        legalWallet = _legalWallet;

        // Mint initial token allocations for each wallet based on the tokenomics provided
        _mint(liquidityWallet, 420_000_000 * 10 ** 18); // 1% to liquidity
        _mint(crowdfundingWallet, 4_200_000_000 * 10 ** 18); // 10% to crowdfunding
        _mint(teamWallet, 8_400_000_000 * 10 ** 18); // 20% to team
        _mint(advisorWallet, 2_100_000_000 * 10 ** 18); // 5% to advisors
        _mint(investorWallet, 6_300_000_000 * 10 ** 18); // 15% to investors
        _mint(reserveFundWallet, 6_300_000_000 * 10 ** 18); // 15% to reserve fund
        _mint(communityWallet, 8_400_000_000 * 10 ** 18); // 20% to community & ecosystem
        _mint(marketingWallet, 4_200_000_000 * 10 ** 18); // 10% to marketing & partnerships
        _mint(legalWallet, 1_680_000_000 * 10 ** 18); // 4% to legal & compliance
    }

    /**
     * @dev Transfer function that applies a tax on non-whitelisted users.
     * Overridden from the default ERC20 transfer function.
     * @param recipient The address to which tokens will be transferred.
     * @param amount The amount of tokens to be transferred.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 taxAmount = 0;

        // Apply tax only if the sender is not whitelisted
        if (!isWhitelisted[msg.sender]) {
            taxAmount = (amount * taxRate) / 10000;
        }

        // Calculate the amount to be transferred after tax
        uint256 amountAfterTax = amount - taxAmount;

        // Transfer the amount after tax to the recipient
        _transfer(msg.sender, recipient, amountAfterTax);

        // Transfer the tax amount (if any) to the owner (could be used for governance, burn, or rewards)
        if (taxAmount > 0) {
            _transfer(msg.sender, owner(), taxAmount);
        }

        return true;
    }

    /**
     * @dev Function to allow token purchase during the ICO using USDT.
     * The user must approve the transfer of USDT before calling this function.
     * Only allows a maximum purchase of 100 million PAY per period with a cooldown.
     * If the user purchases exactly 100 million PAY, they will be whitelisted.
     * @param amountInUSDT The amount of USDT being spent to buy PAY tokens.
     */
    function buyTokens(uint256 amountInUSDT) external nonReentrant {
        require(amountInUSDT > 0, "Must send USDT to buy tokens");

        // Convert USDT to PAY tokens using the rate (1 USDT = 1000 PAY)
        uint256 tokensToMint = amountInUSDT * 1000;

        // Check if the purchase exceeds the max limit (100 million PAY)
        require(tokensToMint <= MAX_PURCHASE_LIMIT, "Purchase exceeds maximum allowed amount");

        // Check if the cooldown period has passed since the last purchase
        require(block.timestamp >= lastPurchaseTime[msg.sender] + COOLDOWN_PERIOD, "Please wait before buying again");

        // Ensure the buyer has approved the USDT transfer
        require(usdtContract.allowance(msg.sender, address(this)) >= amountInUSDT, "USDT allowance too low");

        // Transfer USDT from the buyer to the contract
        bool success = usdtContract.transferFrom(msg.sender, address(this), amountInUSDT);
        require(success, "USDT transfer failed");

        // Mint PAY tokens and send them to the buyer
        _mint(msg.sender, tokensToMint);

        // Update the last purchase time
        lastPurchaseTime[msg.sender] = block.timestamp;

        // Whitelist the user if they purchase exactly 100 million PAY tokens
        if (tokensToMint == MAX_PURCHASE_LIMIT) {
            isWhitelisted[msg.sender] = true;
            emit UserWhitelisted(msg.sender);
        }

        // Emit an event for the token purchase
        emit TokensPurchased(msg.sender, tokensToMint);
    }
}
