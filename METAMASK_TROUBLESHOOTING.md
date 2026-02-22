# MetaMask Connection Troubleshooting Guide

## Common Issues and Solutions

### Issue: "Failed to connect to MetaMask"

#### 1. MetaMask Not Installed
**Solution:**
- Install MetaMask browser extension from https://metamask.io/download/
- Refresh the page after installation
- Make sure MetaMask is unlocked

#### 2. MetaMask Connector Script Not Loaded
**Error:** "MetaMask connector script not loaded"

**Solution:**
- Check that `web/metamask_connector.js` exists
- Verify `web/index.html` includes: `<script src="metamask_connector.js"></script>`
- Clear browser cache and rebuild: `flutter clean && flutter build web`
- Restart the development server

#### 3. User Rejected Connection
**Error:** "Connection rejected" or "User rejected"

**Solution:**
- Click MetaMask extension icon
- Check for pending connection requests
- Approve the connection when prompted
- Try connecting again

#### 4. Wrong Network
**Error:** Connected but on wrong network

**Solution:**
- The app should automatically switch to Sepolia testnet
- If not, manually switch in MetaMask:
  - Click network dropdown
  - Select "Sepolia" or add custom network:
    - Network Name: Sepolia
    - RPC URL: https://rpc.sepolia.org
    - Chain ID: 11155111
    - Currency Symbol: ETH

#### 5. JavaScript Interop Issues (Web)
**Error:** "Error connecting MetaMask on web"

**Solution:**
- Ensure you're running on web platform: `flutter run -d chrome`
- Check browser console for JavaScript errors (F12)
- Verify `dart:js` package is available
- Try hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)

#### 6. Mobile Platform Issues
**Error:** Mobile connection not working

**Solution:**
- MetaMask mobile connection requires WalletConnect SDK (not yet implemented)
- For now, use web version in mobile browser with MetaMask extension
- Or use Chrome on mobile with MetaMask extension

## Testing Steps

1. **Verify MetaMask Installation:**
   - Open browser console (F12)
   - Type: `typeof window.ethereum`
   - Should return: `"object"` (not `"undefined"`)

2. **Verify Script Loading:**
   - Open browser console
   - Type: `typeof window.connectMetaMask`
   - Should return: `"function"`

3. **Test Connection Manually:**
   - Open browser console
   - Type: `window.connectMetaMask()`
   - Should return a promise with connection result

4. **Check Network:**
   - Open MetaMask extension
   - Verify you're on Sepolia testnet
   - If not, switch networks

## Debug Mode

To see detailed error messages:

1. Open browser console (F12)
2. Look for error messages when clicking "Sign In With Metamask"
3. Check the error message in the app's error display

## Quick Fixes

### Fix 1: Rebuild Web Assets
```bash
flutter clean
flutter build web
flutter run -d chrome
```

### Fix 2: Clear Browser Cache
- Chrome: Settings > Privacy > Clear browsing data
- Or use Incognito/Private mode

### Fix 3: Verify File Structure
```
web/
  ├── index.html (should include metamask_connector.js)
  └── metamask_connector.js (should exist)
```

### Fix 4: Check MetaMask Status
- Ensure MetaMask extension is enabled
- Unlock MetaMask wallet
- Check for pending notifications in MetaMask

## Still Not Working?

1. **Check Browser Console:**
   - Open DevTools (F12)
   - Look for red error messages
   - Share error details for further debugging

2. **Verify Platform:**
   - Web: Should work with MetaMask extension
   - Mobile: Currently requires web browser with extension

3. **Test in Different Browser:**
   - Try Chrome, Firefox, or Edge
   - Ensure MetaMask extension is installed

4. **Check Network Connection:**
   - Ensure internet connection is active
   - Test RPC endpoint: https://rpc.sepolia.org

## Development Mode (Testing Without MetaMask)

For development/testing, you can temporarily modify the code to use a mock address. However, this should only be used for UI testing, not production.


