// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721Royalty, Ownable {

    uint256 private s_tokenId;

    constructor() ERC721("TestNFT", "TNFT") Ownable(msg.sender) {}

    function mint(address to) external onlyOwner {
        s_tokenId++;

        _safeMint(to, s_tokenId);

        // 5% royalty
        _setTokenRoyalty(s_tokenId, owner(), 500);
    }
}
