# NFT Marketplace Smart Contract

---

### Sepolia(Testnet) deployed address 
- [https://sepolia.etherscan.io/address/0x8cF231c0eD4ABacB1e9601cc06593992617b219a]

---

## Overview

The **NFTMarketplace** contract is a fully on-chain marketplace for buying, selling, and making offers on ERC-721 NFTs. It supports:

- Direct listing and purchase of NFTs
- Escrowed offers with expiration
- Marketplace fees
- Royalty payments (ERC-2981 standard)
- Admin functions for fee management
- Security features like reentrancy guard

It is deployed on **Sepolia testnet** for safe testing before mainnet deployment.

---

## Architecture

### Contract Inheritance
- `Ownable`: Only the contract owner can modify marketplace fees and fee recipient.
- `ReentrancyGuard`: Prevents reentrancy attacks for buy/sell/offer functions.
- `Address`: Utility for safely transferring ETH.

### Data Structures

#### Listing
Represents an NFT listed for sale.

```solidity
struct Listing {
    address seller;  // NFT owner
    uint96 price;    // Listing price in wei
    uint64 listedAt; // Timestamp of listing
}
```

#### Offer
Represents an escrowed offer by a buyer.

```solidity
struct Offer {
    address buyer;     // Buyer making the offer
    uint96 price;      // Offer price in wei
    uint64 expiresAt;  // Expiration timestamp
}
```

### Storage Variables
- `s_listings`: Stores listings per NFT contract & tokenId.
- `s_offers`: Stores offers per NFT contract, tokenId, and buyer.
- `marketplaceFee`: Marketplace fee in basis points (e.g., 250 = 2.5%).
- `feeRecipient`: Address that receives marketplace fees.

---

## Functionalities

### 1. Listing NFTs
- **listItem**: Only the NFT owner can list; price must be > 0; NFT approval required.
- **cancelListing**: Owner can remove NFT from listing.
- **updateListing**: Owner can change listing price.

### 2. Buying NFTs
- **buyItem**: Buy listed NFT.
  - Checks: NFT listed, buyer not seller, ETH >= price.
  - Handles marketplace fee and ERC-2981 royalties.
  - Transfers NFT to buyer and remaining ETH to seller.

### 3. Offer System (Escrowed)
- **makeOffer**: Buyer locks ETH as an offer.
- **cancelOffer**: Buyer cancels and gets ETH back.
- **acceptOffer**: NFT owner accepts buyer's offer.
  - Handles marketplace fee, royalties, NFT transfer.

### 4. Admin Functions
- **updateMarketplaceFee**: Max 10%.
- **updateFeeRecipient**: Change fee recipient.
- Only callable by `owner()`.

### 5. View Functions
- **getListing**: Returns NFT listing.
- **getOffer**: Returns NFT offer.
- **marketplaceFee**: Returns fee.
- **feeRecipient**: Returns fee recipient.
- **owner**: Returns contract owner.

### 6. Events
Frontend can listen to events:

| Event                 | Triggered By         | Data                                  |
| --------------------- | -------------------- | ------------------------------------- |
| ItemListed            | listItem             | seller, nft, tokenId, price           |
| ItemCanceled          | cancelListing        | seller, nft, tokenId                  |
| PriceUpdated          | updateListing        | seller, nft, tokenId, newPrice        |
| ItemBought            | buyItem              | buyer, nft, tokenId, price            |
| OfferMade             | makeOffer            | buyer, nft, tokenId, price, expiresAt |
| OfferCanceled         | cancelOffer          | buyer, nft, tokenId                   |
| OfferAccepted         | acceptOffer          | seller, buyer, nft, tokenId, price    |
| MarketplaceFeeUpdated | updateMarketplaceFee | newFee                                |
| FeeRecipientUpdated   | updateFeeRecipient   | newRecipient                          |

### 7. Security & Constraints
- ReentrancyGuard prevents reentrancy attacks.
- Ownership checks for listing, updating, canceling, and accepting offers.
- Approval checks for NFTs.
- Price must be > 0.
- Expired offers cannot be accepted.
- Cannot buy own NFT.
- Supports ERC-2981 royalties.

### 8. Limitations
1. Testnet deployment on Sepolia.
2. Supports ERC-721 only.
3. Single offer per buyer per NFT.
4. Marketplace fee capped at 10%.
5. Fully on-chain (gas costs apply).
6. ETH payments only.
7. Expired offers remain until canceled.

### 9. Recommended Frontend Integration
- **Stack**: Next.js 16 + TypeScript + Ethers.js
- **Components**:
  - Marketplace List Page
  - NFT Card Component
  - Offer Modal
  - Admin Panel
  - Event Listeners
- **Wallet Integration**: MetaMask or any EVM wallet.










