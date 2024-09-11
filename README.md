# cannacoin-pay-project
# whitepaper
This contract is a comprehensive smart contract for **Cannacoin PAY ($PAY)**, which manages token minting, purchases, staking, vesting, and trading while enforcing taxes, cooldowns, and anti-gray trading mechanisms. Below is a breakdown of its components:

### 1. **Token Configuration**
- **MAX_SUPPLY**: The maximum supply of $PAY tokens is capped at 42 billion tokens.
- **MAX_PURCHASE_LIMIT**: Limits the maximum amount of $PAY tokens that can be purchased in one transaction to 100 million tokens.
- **cooldownPeriod**: A period (default of 1 day) enforced between token purchases by an individual, which can be updated by the contract owner.
- **taxRate**: Defines the tax (6.9%) applied to token transfers, with flexibility to increase or decrease based on trading frequency and holding duration.
- **stakingPenaltyRate**: Applies a 5% penalty for early withdrawal from staking.
- **minimumStakeDuration**: Users must stake tokens for at least 180 days to avoid penalties.

### 2. **Wallets for Allocation**
The contract has pre-defined wallets for the following:
- **Liquidity**
- **Crowdfunding**
- **Team**
- **Advisors**
- **Investors**
- **Reserve Fund**
- **Community & Ecosystem**
- **Marketing & Partnerships**
- **Legal & Compliance**

These wallets are funded during the initial token minting process.

### 3. **Sliding Tax Scale Mechanism**
- The contract implements a dynamic tax mechanism, where the tax on transfers changes based on the user's activity:
  - **Frequent Traders**: If the user has made a transaction within the last 24 hours, the tax increases to 10%.
  - **Long-Term Holders**: If the user has held their tokens for more than 180 days, the tax is reduced to 4%.
  - **Large Transactions**: For transactions that are more than 0.1% of the total supply, the tax increases to 8%.

### 4. **Purchase of Tokens**
- **buyTokens**: Users can purchase $PAY tokens using **USDT** at a rate of 1 USDT = 1000 $PAY (with adjustments for USDT's 6 decimal places).
- Purchase transactions are subject to the **MAX_PURCHASE_LIMIT** and the **cooldownPeriod** between purchases.
- Upon purchase, users may also be whitelisted if they purchase the maximum amount.

### 5. **Staking Functionality**
- **Stake**: Users can stake their $PAY tokens to earn rewards, access governance features, claim discounts, or gain priority access to features. Staked tokens are locked for a minimum of 180 days.
- **Unstake**: Users can unstake their tokens, but if they unstake before the minimum duration, they are subject to a 5% penalty.
- **Governance Rights & Discounts**: Users can claim governance rights after staking for 180 days, discounts after 90 days, and priority access after 30 days.

### 6. **Anti-Gray Trading & Blacklisting**
- The contract limits high-frequency trading by capping the number of transfers a user can make in a 24-hour period.
- **Blacklisting**: Malicious users can be blacklisted, preventing them from transferring tokens. The owner has the ability to add or remove users from the blacklist.

### 7. **Vesting Schedule**
The contract includes a vesting mechanism for team members, advisors, and investors:
- **VestingSchedule**: Defines the vesting period, start time, and amount of tokens vested for each beneficiary.
- **releaseVestedTokens**: This function allows tokens to be released over time based on a cliff period and vesting duration.

### 8. **Events**
The contract emits several events:
- **TokensPurchased**: Emitted when a user purchases tokens.
- **TaxRateUpdated**: Emitted when the tax rate is updated.
- **UserWhitelisted**: Emitted when a user is whitelisted.
- **TokensVested**: Emitted when tokens are vested for a beneficiary.
- **TokensReleased**: Emitted when vested tokens are released to a beneficiary.
- **Staked**: Emitted when a user stakes tokens.
- **Unstaked**: Emitted when a user unstakes tokens.
- **ClaimedGovernanceRights**, **ClaimedDiscount**, **GainedAccess**: Emitted when users claim governance rights, discounted fees, or priority access.

### 9. **Adjustable Cooldown Period**
- The owner can adjust the cooldown period between purchases via the **setCooldownPeriod** function.

### **Summary:**
This contract manages the entire lifecycle of the $PAY token, from minting and token purchases to staking, vesting, and anti-abuse measures. It encourages long-term holding and discourages frequent trading through its dynamic tax system. It also offers incentives for staking while providing team members and advisors with vesting schedules to ensure proper token distribution over time.
