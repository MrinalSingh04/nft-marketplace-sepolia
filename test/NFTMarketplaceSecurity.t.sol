// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/TestNFT.sol";

contract NFTMarketplaceSecurityTest is Test {

    NFTMarketplace market;
    TestNFT nft;

    address seller = address(1);
    address attacker = address(2);
    address feeRecipient = address(3);

    function setUp() public {
        market = new NFTMarketplace(250, feeRecipient);
        nft = new TestNFT();

        nft.mint(seller);
    }

    /*//////////////////////////////////////////////////////////////
                        NON OWNER CANNOT LIST
    //////////////////////////////////////////////////////////////*/

    function testCannotListIfNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotOwner.selector);

        market.listItem(address(nft), 1, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        MUST APPROVE MARKET
    //////////////////////////////////////////////////////////////*/

    function testCannotListWithoutApproval() public {
        vm.startPrank(seller);

        vm.expectRevert(NFTMarketplace.NotApproved.selector);
        market.listItem(address(nft), 1, 1 ether);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BUY MUST SEND ENOUGH ETH
    //////////////////////////////////////////////////////////////*/

    function testBuyFailsIfUnderpaid() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.listItem(address(nft), 1, 1 ether);
        vm.stopPrank();

        vm.deal(attacker, 0.5 ether);

        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.InsufficientValue.selector);

        market.buyItem{value: 0.5 ether}(address(nft), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        CANNOT BUY OWN NFT
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyOwnNFT() public {
    vm.deal(seller, 1 ether);

    vm.startPrank(seller);

    nft.approve(address(market), 1);
    market.listItem(address(nft), 1, 1 ether);

    vm.expectRevert(NFTMarketplace.CannotBuyOwnNFT.selector);
    market.buyItem{value: 1 ether}(address(nft), 1);

    vm.stopPrank();
}


    /*//////////////////////////////////////////////////////////////
                        CANNOT BUY UNLISTED NFT
    //////////////////////////////////////////////////////////////*/

    function testCannotBuyUnlistedNFT() public {
        vm.deal(attacker, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(NFTMarketplace.NotListed.selector);

        market.buyItem{value: 1 ether}(address(nft), 1);
    }
}
