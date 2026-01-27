//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Nft is ERC721 {
    error Nft_OnlyOwnerCanCallMint();

    uint256 private s_tokenIdCounter;
    mapping(uint256 => string) private s_tokenIdToUri;
    address immutable i_owner;

    constructor(
        string memory nftName,
        string memory nftSymbol
    ) ERC721(nftName, nftSymbol) {
        s_tokenIdCounter = 0;
        i_owner = msg.sender;
    }

    modifier requireOwner() {
        if (msg.sender != i_owner) {
            revert Nft_OnlyOwnerCanCallMint();
        }
        _;
    }

    function mint(string memory tokenURI) external requireOwner {
        s_tokenIdToUri[s_tokenIdCounter] = tokenURI;
        _safeMint(msg.sender, s_tokenIdCounter);
        s_tokenIdCounter++;
    }

    function getTokenURI(
        uint256 tokenId
    ) external view returns (string memory) {
        return s_tokenIdToUri[tokenId];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
