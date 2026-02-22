# Security

## Smart contract

- **ReentrancyGuard**: Payment and refund paths use a `nonReentrant` modifier so that external calls (ETH transfer) cannot re-enter `payBooking`, `completeBooking`, or `cancelBooking`.
- **Access control**: Only the booking owner can cancel or complete a booking; only the station owner can update/deactivate their P2P station; only registered users can create bookings and use escrow.
- **Double-booking**: Time conflict checks in `createBooking` prevent overlapping bookings at the same station.
- **Escrow**: Charging payments are held in the contract until completion; cancellation triggers a refund to the payer. No direct EOA transfer for on-chain bookings when escrow is used.
- **Fraud**: Contract does not allow completing a booking without prior payment; refund is only to `booking.userAddress`. Tamper-proof records (transactions, bookings) are immutable on-chain.

## App

- **Signing**: All on-chain transactions are signed by the user via MetaMask (no private keys in the app).
- **Sensitive config**: Contract address and RPC URLs are in code; for production, consider environment-based config. Never commit private keys or `.env`.
- **Local data**: Wallet address and cache are stored in SharedPreferences; clear local cache via Profile → Privacy & data when needed.

## Reporting

If you discover a vulnerability, please report it responsibly (e.g. via a private channel to the maintainers rather than a public issue).
