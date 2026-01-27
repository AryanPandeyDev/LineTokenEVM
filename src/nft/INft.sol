//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title INft
 * @notice Interface for the Nft contract
 */
interface INft is IERC721 {
    /// @notice Thrown when a non-owner tries to call the mint function
    error Nft_OnlyOwnerCanCallMint();

    /**
     * @notice Mints a new NFT with the specified token URI
     * @dev Only the owner can call this function
     * @param tokenURI The URI for the token metadata
     */
    function mint(string memory tokenURI) external;

    /**
     * @notice Returns the token URI for a given token ID
     * @param tokenId The ID of the token
     * @return The URI string for the token
     */
    function getTokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @notice Returns the owner address of the contract
     * @return The address of the contract owner
     */
    function getOwner() external view returns (address);
}
