// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "./ERC721Rolyalty.sol";

contract StartfiNFT is ERC721Rolyalty, ERC721PresetMinterPauserAutoId {
    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721PresetMinterPauserAutoId (   name,  symbol,   baseTokenURI){}

    function mintWithRoyalty(address to,uint8 share,uint8 base) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _supportRoyalty(_tokenIdTracker.current(),  to,   share,  base);
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }
}
