// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;
 import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC721MinterPauser.sol";

 import "./ERC721Royalty.sol";


contract StartfiRoyaltyNFT is  ERC721Royalty , ERC721MinterPauser{
         using Counters for Counters.Counter;

     Counters.Counter private _tokenIdTracker;

    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721MinterPauser (   name,  symbol,   baseTokenURI){}

    function mintWithRoyalty(address to,uint8 share,uint8 base) external virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _supportRoyalty(_tokenIdTracker.current(),  to,   share,  base);
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
        function mint(address to) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }


// 0x2a55205a
     /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override( ERC721MinterPauser) returns (bool) {
        return  interfaceId == supportsRoyalty()||super.supportsInterface(interfaceId);
    }
}
