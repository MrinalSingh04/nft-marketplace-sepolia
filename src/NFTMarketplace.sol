// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    using Address for address payable;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Listing {
        address seller; // 20 bytes
        uint96 price; // 12 bytes
        uint64 listedAt; // 8 bytes
    }

    struct Offer {
        address buyer; // 20 bytes
        uint96 price; // 12 bytes
        uint64 expiresAt; // 8 bytes
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NotApproved();
    error AlreadyListed();
    error NotListed();
    error PriceMustBeAboveZero();
    error InsufficientValue();
    error OfferExpired();
    error OfferNotFound();
    error CannotBuyOwnNFT();
    error FeeTooHigh();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ItemListed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price);
    event ItemCanceled(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event ItemBought(address indexed buyer, address indexed nft, uint256 indexed tokenId, uint256 price);
    event PriceUpdated(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 newPrice);

    event OfferMade(
        address indexed buyer, address indexed nft, uint256 indexed tokenId, uint256 price, uint64 expiresAt
    );
    event OfferCanceled(address indexed buyer, address indexed nft, uint256 indexed tokenId);
    event OfferAccepted(
        address indexed seller, address indexed buyer, address indexed nft, uint256 tokenId, uint256 price
    );

    event MarketplaceFeeUpdated(uint96 newFee);
    event FeeRecipientUpdated(address newRecipient);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // nft => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // nft => tokenId => buyer => Offer
    mapping(address => mapping(uint256 => mapping(address => Offer))) private s_offers;

    uint96 public marketplaceFee; // e.g., 250 = 2.5% (basis points)
    address public feeRecipient;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint96 _marketplaceFee, address _feeRecipient) Ownable(msg.sender) {
        if (_marketplaceFee > 1000) revert FeeTooHigh(); // max 10%
        if (_feeRecipient == address(0)) revert InvalidAddress();

        marketplaceFee = _marketplaceFee;
        feeRecipient = _feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateMarketplaceFee(uint96 _newFee) external onlyOwner {
        if (_newFee > 1000) revert FeeTooHigh();
        marketplaceFee = _newFee;
        emit MarketplaceFeeUpdated(_newFee);
    }

    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) revert InvalidAddress();
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                            LISTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function listItem(address nft, uint256 tokenId, uint96 price) external {
        if (price == 0) revert PriceMustBeAboveZero();

        IERC721 token = IERC721(nft);

        if (token.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (s_listings[nft][tokenId].price > 0) revert AlreadyListed();

        if (token.getApproved(tokenId) != address(this) && !token.isApprovedForAll(msg.sender, address(this))) {
            revert NotApproved();
        }

        s_listings[nft][tokenId] = Listing({seller: msg.sender, price: price, listedAt: uint64(block.timestamp)});

        emit ItemListed(msg.sender, nft, tokenId, price);
    }

    function cancelListing(address nft, uint256 tokenId) external {
        Listing memory listing = s_listings[nft][tokenId];

        if (listing.price == 0) revert NotListed();
        if (listing.seller != msg.sender) revert NotOwner();

        delete s_listings[nft][tokenId];

        emit ItemCanceled(msg.sender, nft, tokenId);
    }

    function updateListing(address nft, uint256 tokenId, uint96 newPrice) external {
        if (newPrice == 0) revert PriceMustBeAboveZero();

        Listing storage listing = s_listings[nft][tokenId];

        if (listing.price == 0) revert NotListed();
        if (listing.seller != msg.sender) revert NotOwner();

        listing.price = newPrice;

        emit PriceUpdated(msg.sender, nft, tokenId, newPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            BUY LOGIC
    //////////////////////////////////////////////////////////////*/

    function buyItem(address nft, uint256 tokenId) external payable nonReentrant {
        Listing memory listing = s_listings[nft][tokenId];

        if (listing.price == 0) revert NotListed();
        if (listing.seller == msg.sender) revert CannotBuyOwnNFT();
        if (msg.value < listing.price) revert InsufficientValue();

        delete s_listings[nft][tokenId];

        uint256 price = listing.price;

        uint256 feeAmount = (price * marketplaceFee) / 10000;
        uint256 sellerAmount = price - feeAmount;

        uint256 royaltyAmount;
        address royaltyReceiver;

        if (IERC165(nft).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) = IERC2981(nft).royaltyInfo(tokenId, price);

            if (royaltyReceiver != address(0) && royaltyAmount > 0) {
                sellerAmount -= royaltyAmount;
            }
        }

        IERC721(nft).safeTransferFrom(listing.seller, msg.sender, tokenId);

        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            payable(royaltyReceiver).sendValue(royaltyAmount);
        }

        payable(feeRecipient).sendValue(feeAmount);
        payable(listing.seller).sendValue(sellerAmount);

        uint256 excess = msg.value - price;
        if (excess > 0) {
            payable(msg.sender).sendValue(excess);
        }

        emit ItemBought(msg.sender, nft, tokenId, price);
    }

    /*//////////////////////////////////////////////////////////////
                            OFFER LOGIC (ESCROWED)
    //////////////////////////////////////////////////////////////*/

    function makeOffer(address nft, uint256 tokenId, uint64 expiresAt) external payable nonReentrant {
        if (msg.value == 0) revert PriceMustBeAboveZero();
        if (expiresAt <= block.timestamp) revert OfferExpired();

        Offer storage existing = s_offers[nft][tokenId][msg.sender];

        if (existing.price > 0) {
            payable(msg.sender).sendValue(existing.price);
        }

        s_offers[nft][tokenId][msg.sender] = Offer({buyer: msg.sender, price: uint96(msg.value), expiresAt: expiresAt});

        emit OfferMade(msg.sender, nft, tokenId, msg.value, expiresAt);
    }

    function cancelOffer(address nft, uint256 tokenId) external nonReentrant {
        Offer memory offer = s_offers[nft][tokenId][msg.sender];
        if (offer.price == 0) revert OfferNotFound();

        delete s_offers[nft][tokenId][msg.sender];

        payable(msg.sender).sendValue(offer.price);

        emit OfferCanceled(msg.sender, nft, tokenId);
    }

    function acceptOffer(address nft, uint256 tokenId, address buyer) external nonReentrant {
        IERC721 token = IERC721(nft);

        if (token.ownerOf(tokenId) != msg.sender) revert NotOwner();

        if (token.getApproved(tokenId) != address(this) && !token.isApprovedForAll(msg.sender, address(this))) {
            revert NotApproved();
        }

        Offer memory offer = s_offers[nft][tokenId][buyer];

        if (offer.price == 0) revert OfferNotFound();
        if (offer.expiresAt <= block.timestamp) revert OfferExpired();

        delete s_offers[nft][tokenId][buyer];

        uint256 price = offer.price;

        uint256 feeAmount = (price * marketplaceFee) / 10000;
        uint256 sellerAmount = price - feeAmount;

        uint256 royaltyAmount;
        address royaltyReceiver;

        if (IERC165(nft).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyReceiver, royaltyAmount) = IERC2981(nft).royaltyInfo(tokenId, price);

            if (royaltyReceiver != address(0) && royaltyAmount > 0) {
                sellerAmount -= royaltyAmount;
            }
        }

        token.safeTransferFrom(msg.sender, buyer, tokenId);

        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            payable(royaltyReceiver).sendValue(royaltyAmount);
        }

        payable(feeRecipient).sendValue(feeAmount);
        payable(msg.sender).sendValue(sellerAmount);

        emit OfferAccepted(msg.sender, buyer, nft, tokenId, price);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function getListing(address nft, uint256 tokenId) external view returns (Listing memory) {
        return s_listings[nft][tokenId];
    }

    function getOffer(address nft, uint256 tokenId, address buyer) external view returns (Offer memory) {
        return s_offers[nft][tokenId][buyer];
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}
