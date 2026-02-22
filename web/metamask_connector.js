// MetaMask connector for web platform
// This file should be included in web/index.html

// Get current account without prompting (eth_accounts). Use to recover saved wallet.
window.getMetaMaskAccount = async function() {
  if (typeof window.ethereum === 'undefined') {
    return null;
  }
  try {
    const accounts = await window.ethereum.request({ method: 'eth_accounts' });
    if (accounts && accounts.length > 0) return accounts[0];
  } catch (e) {
    console.warn('getMetaMaskAccount:', e);
  }
  return null;
};

window.connectMetaMask = async function() {
  // Check if MetaMask is installed
  if (typeof window.ethereum === 'undefined') {
    return {
      success: false,
      error: 'MetaMask is not installed. Please install MetaMask browser extension from https://metamask.io/download/'
    };
  }

  try {
    // Request account access
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts'
    });
    
    // Check if we got accounts
    if (!accounts || accounts.length === 0) {
      return {
        success: false,
        error: 'No accounts found. Please unlock MetaMask and try again.'
      };
    }
    
    // Get the first account
    const address = accounts[0];
    
    if (!address) {
      return {
        success: false,
        error: 'Failed to get wallet address from MetaMask'
      };
    }
    
    // Get chain ID to verify network (optional check)
    try {
      const chainId = await window.ethereum.request({
        method: 'eth_chainId'
      });
      console.log('Connected to chain:', chainId);
    } catch (e) {
      console.warn('Could not get chain ID:', e);
    }
    
    return {
      success: true,
      address: address
    };
  } catch (error) {
    // Handle specific MetaMask errors
    let errorMessage = error.message || 'Unknown error';
    
    if (error.code === 4001) {
      errorMessage = 'User rejected the connection request. Please approve in MetaMask.';
    } else if (error.code === -32002) {
      errorMessage = 'Connection request already pending. Please check MetaMask.';
    }
    
    return {
      success: false,
      error: errorMessage
    };
  }
};

window.switchToSepolia = async function() {
  if (typeof window.ethereum === 'undefined') {
    return { success: false, error: 'MetaMask not found' };
  }

  try {
    // First, try to switch to Sepolia
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0xaa36a7' }], // Sepolia (11155111)
    });
    return { success: true };
  } catch (switchError) {
    // If the chain doesn't exist (error code 4902), add it
    if (switchError.code === 4902) {
      try {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: '0xaa36a7', // 11155111 in hex
            chainName: 'Sepolia',
            nativeCurrency: {
              name: 'ETH',
              symbol: 'ETH',
              decimals: 18
            },
            rpcUrls: ['https://rpc.sepolia.org'],
            blockExplorerUrls: ['https://sepolia.etherscan.io']
          }],
        });
        return { success: true };
      } catch (addError) {
        return { 
          success: false, 
          error: `Failed to add Sepolia network: ${addError.message || addError.toString()}` 
        };
      }
    }
    
    // User rejected the switch
    if (switchError.code === 4001) {
      return { 
        success: false, 
        error: 'Network switch rejected. Please switch to Sepolia testnet manually in MetaMask.' 
      };
    }
    
    return { 
      success: false, 
      error: `Failed to switch network: ${switchError.message || switchError.toString()}` 
    };
  }
};

// Simple ABI encoder for contract function calls
// This is a simplified version - for production, use ethers.js or web3.js
window.encodeFunctionCall = function(functionSignature, params) {
  // This is a very basic implementation
  // In production, you should use a proper ABI encoder like ethers.js
  // For now, we'll return a placeholder
  // The actual encoding would require the full ABI and proper parameter encoding
  return '0x' + functionSignature.substring(0, 8); // Function selector (first 4 bytes of keccak256 hash)
};

// Send contract transaction via MetaMask
window.sendContractTransaction = async function(contractAddress, functionName, params, fromAddress) {
  if (typeof window.ethereum === 'undefined') {
    return { success: false, error: 'MetaMask not found' };
  }

  try {
    // Note: This is a simplified version
    // In production, you should use ethers.js or web3.js to properly encode the function call
    // For now, we'll use a workaround where the contract function is called via a library
    
    // The proper way would be:
    // 1. Load ethers.js or web3.js
    // 2. Create contract instance
    // 3. Call the function which will prompt MetaMask
    
    // For this implementation, we'll need to include ethers.js in the HTML
    // or use web3.js to encode and send the transaction
    
    return {
      success: false,
      error: 'Contract transaction encoding requires ethers.js or web3.js. Please include one of these libraries.'
    };
  } catch (error) {
    return {
      success: false,
      error: error.message || error.toString()
    };
  }
};

