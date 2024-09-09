// Web3.js setup
let web3;
let userAccount;
let usdtContract;
let payTokenContract;

const USDT_ADDRESS = '<USDT_CONTRACT_ADDRESS>';  // Insert the USDT contract address here
const PAY_CONTRACT_ADDRESS = '<PAY_TOKEN_CONTRACT_ADDRESS>';  // Insert your deployed PAY contract address here
const PAY_CONTRACT_ABI = [/* Your PAY contract ABI here */];  // Insert PAY token contract ABI here
const USDT_CONTRACT_ABI = [/* USDT contract ABI here */];  // Insert USDT ABI here

// DOM Elements
const connectWalletBtn = document.getElementById('connectWalletBtn');
const approveTokensBtn = document.getElementById('approveTokensBtn');
const buyTokensBtn = document.getElementById('buyTokensBtn');
const amountToBuyInput = document.getElementById('amountToBuy');
const walletAddressDisplay = document.getElementById('walletAddress');
const usdtBalanceDisplay = document.getElementById('usdtBalance');

// Disable buttons by default
approveTokensBtn.disabled = true;
buyTokensBtn.disabled = true;
amountToBuyInput.disabled = true;

// Function to connect MetaMask wallet
connectWalletBtn.addEventListener('click', async () => {
    if (typeof window.ethereum !== 'undefined') {
        web3 = new Web3(window.ethereum);
        try {
            const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
            userAccount = accounts[0];
            walletAddressDisplay.innerHTML = `Wallet: ${userAccount}`;

            // Initialize USDT and PAY contracts
            usdtContract = new web3.eth.Contract(USDT_CONTRACT_ABI, USDT_ADDRESS);
            payTokenContract = new web3.eth.Contract(PAY_CONTRACT_ABI, PAY_CONTRACT_ADDRESS);

            // Enable amount input and fetch USDT balance
            amountToBuyInput.disabled = false;
            await getUSDTBalance();

            // Enable Approve button after wallet connection and valid input
            amountToBuyInput.addEventListener('input', () => {
                const amountToBuy = amountToBuyInput.value;
                if (amountToBuy && parseFloat(amountToBuy) > 0) {
                    approveTokensBtn.disabled = false;
                    approveTokensBtn.title = '';  // Remove tooltip if input is valid
                } else {
                    approveTokensBtn.disabled = true;
                    approveTokensBtn.title = 'Enter a valid USDT amount';
                }
            });
        } catch (error) {
            console.error('Error connecting wallet:', error);
        }
    } else {
        alert('Please install MetaMask to use this feature.');
    }
});

// Fetch USDT Balance
async function getUSDTBalance() {
    try {
        const balance = await usdtContract.methods.balanceOf(userAccount).call();
        usdtBalanceDisplay.innerHTML = `USDT Balance: ${web3.utils.fromWei(balance, 'ether')}`;
    } catch (error) {
        console.error('Error fetching USDT balance:', error);
        usdtBalanceDisplay.innerHTML = 'USDT Balance: Error';
    }
}

// Approve USDT for token purchase
approveTokensBtn.addEventListener('click', async () => {
    const amountToBuy = amountToBuyInput.value;

    if (!amountToBuy || amountToBuy <= 0) {
        alert('Please enter a valid amount.');
        return;
    }

    // Convert amount to WEI (USDT has 6 decimals, so adjust accordingly if needed)
    const amountInUSDT = web3.utils.toWei(amountToBuy, 'ether'); // Adjust for USDT decimal places

    try {
        // Approve the PAY contract to transfer USDT on behalf of the user
        await usdtContract.methods.approve(PAY_CONTRACT_ADDRESS, amountInUSDT).send({ from: userAccount });
        alert('USDT Approved!');
        buyTokensBtn.disabled = false;  // Enable buy button after approval
        buyTokensBtn.title = '';  // Remove tooltip after approval
    } catch (error) {
        console.error('Approval failed:', error);
        alert('Approval failed. Please try again.');
    }
});

// Buy Tokens function
buyTokensBtn.addEventListener('click', async () => {
    const amountToBuy = amountToBuyInput.value;

    if (!amountToBuy || amountToBuy <= 0) {
        alert('Please enter a valid amount.');
        return;
    }

    // Convert amount to WEI (USDT has 6 decimals)
    const amountInUSDT = web3.utils.toWei(amountToBuy, 'ether');

    try {
        // Call buyTokens() from the PAY contract to complete the purchase
        await payTokenContract.methods.buyTokens(amountInUSDT).send({ from: userAccount });
        alert('Purchase successful!');

        // Refresh the USDT balance after purchase
        await getUSDTBalance();

        // Reset input and disable buy button
        amountToBuyInput.value = '';
        buyTokensBtn.disabled = true;
    } catch (error) {
        console.error('Purchase failed:', error);
        alert('Purchase failed. Please try again.');
    }
});
