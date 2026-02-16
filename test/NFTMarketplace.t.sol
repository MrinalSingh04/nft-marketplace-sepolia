// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/TestNFT.sol";

contract NFTMarketplaceTest is Test {

    NFTMarketplace marketplace;
    TestNFT nft;

    address seller = address(1);
    address buyer = address(2);
    address feeRecipient = address(3);

    uint96 marketplaceFee = 250; // 2.5%

    // ✅ allows this contract to receive royalty ETH
    receive() external payable {}

    function setUp() public {
        marketplace = new NFTMarketplace(marketplaceFee, feeRecipient);
        nft = new TestNFT();

        nft.mint(seller);

        vm.deal(buyer, 10 ether);
    }

    function testListItem() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), 1);
        marketplace.listItem(address(nft), 1, 1 ether);

        NFTMarketplace.Listing memory listing =
            marketplace.getListing(address(nft), 1);

        assertEq(listing.price, 1 ether);
        assertEq(listing.seller, seller);

        vm.stopPrank();
    }

    function testBuyItemWithRoyaltyAndFee() public {
        // seller lists
        vm.startPrank(seller);
        nft.approve(address(marketplace), 1);
        marketplace.listItem(address(nft), 1, 1 ether);
        vm.stopPrank();

        // balances before
        uint256 sellerBalanceBefore = seller.balance;
        uint256 feeBalanceBefore = feeRecipient.balance;
        uint256 royaltyBalanceBefore = address(this).balance;

        // buyer purchases
        vm.prank(buyer);
        marketplace.buyItem{value: 1 ether}(address(nft), 1);

        // ownership transferred
        assertEq(nft.ownerOf(1), buyer);

        // fee = 2.5%
        uint256 expectedFee = (1 ether * 250) / 10000;
        assertEq(feeRecipient.balance, feeBalanceBefore + expectedFee);

        // royalty = 5%
        uint256 royalty = (1 ether * 500) / 10000;
        assertEq(address(this).balance, royaltyBalanceBefore + royalty);

        // seller receives remainder
        uint256 sellerExpected = 1 ether - expectedFee - royalty;
        assertEq(seller.balance, sellerBalanceBefore + sellerExpected);
    }
}
