// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Token/ITendies.sol";
import "Bonding/IBondNft.sol";
import "Bonding/IVestingCurve.sol";


contract BondNft is ERC721Enumerable, Ownable {
    using Strings for uint256;

    mapping(uint256 => IBondNft.Bond) private bondData;

    uint256 private currentTokenId;
    string private baseURI;
    IVestingCurve private vestingCurve;
    ITendies public tendiesToken;
    address public minter;

    constructor(string memory _baseURI, address _vestingCurve, address _tendieToken) ERC721("TendieBond", "BOND") {
        baseURI = _baseURI;
        vestingCurve = IVestingCurve(_vestingCurve);
        tendiesToken = ITendies(_tendieToken);
        currentTokenId = 0;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mintBond(address recipient, IBondNft.Bond memory bond) public onlyMinter returns (uint256) {
        uint256 tokenId = currentTokenId;
        currentTokenId++;
        tendiesToken.mintRewards(0, bond.payout, address(this));
        _mint(recipient, tokenId);
        bondData[tokenId] = bond;
        return tokenId;
    }

    function getBondData(uint256 tokenId) public view returns (IBondNft.Bond memory bond) {
        return bondData[tokenId];
    }

    function setMinter(address newMinter) public onlyOwner {
        minter = newMinter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Only the minter can call this function");
        _;
    }

    function claimBond(uint256 tokenId) external returns (uint256) {
        require(msg.sender == ownerOf(tokenId), "not owner");
        uint256 payoutT1 = vestingCurve.getVestedPayoutAtTime(bondData[tokenId].payout, bondData[tokenId].vestingTerm, bondData[tokenId].vestingStartTimestamp, block.timestamp);
        if (bondData[tokenId].payoutClaimed < payoutT1) {
            uint256 toClaim = payoutT1 - bondData[tokenId].payoutClaimed;
            IERC20(address(tendiesToken)).approve(address(this),toClaim);
            IERC20(address(tendiesToken)).transferFrom(address(this), msg.sender, toClaim);
            bondData[tokenId].payoutClaimed = payoutT1;
            bondData[tokenId].lastClaimTimestamp = block.timestamp;
            return toClaim;
        } else {
            return 0;
        }

    }

}
