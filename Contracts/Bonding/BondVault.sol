pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./IBondDeposit.sol";
import "./IBondVault.sol";
import "./IBondNft.sol";

contract BondVault is IBondVault {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => uint256) public totalPayouts;
    mapping(address => EnumerableSet.UintSet) private bondsDeposited;
    IERC721 public bondNft;
    IBondNft public bondNftIBond;
    IERC20 public tendies;
    IBondDeposit public bondDeposit;

    constructor(
        address _bondNft,
        address _tendies,
        address _bondContract,
        address _bondNftIBond
    ) {
        bondNft = IERC721(_bondNft);
        tendies = IERC20(_tendies);
        bondDeposit = IBondDeposit(_bondContract);
        bondNftIBond = IBondNft(_bondNftIBond);
    }

    function bondPayoutAmount(address _depositor)
        external
        view
        override
        returns (uint256 payoutTotal)
    {
        return totalPayouts[_depositor];
    }

    function bondPayoutAmountDivSupply(address _depositor)
        external
        view
        override
        returns (uint256 payoutSupplyPercent)
    {
        uint256 totalSupply = tendies.totalSupply();
        uint256 depositorBalance = totalPayouts[_depositor];

        //Percent adjusted by 1000 for increased accuracy
        payoutSupplyPercent = (depositorBalance * 100 * 1000) / totalSupply;
    }

    function bondPayoutAmountDivBondedSupply(address _depositor)
        external
        view
        override
        returns (uint256 payoutBondedPercent)
    {
        uint256 totalBonded = bondDeposit.totalPayoutGiven();
        uint256 depositorBalance = totalPayouts[_depositor];

        //Percent adjusted by 1000 for increased accuracy
        payoutBondedPercent = (depositorBalance * 100 * 1000) / totalBonded;
    }

    function depositNfts(uint256[] calldata tokenIds) external {

        for (uint256 i = 0; i < tokenIds.length;) {
            uint256 tokenId = tokenIds[i];
            require(bondNft.ownerOf(tokenId) == msg.sender, "Not Owner");

            IBondNft.Bond memory bond = bondNftIBond.getBondData(tokenId);

            require(bond.payoutClaimed == bond.payout, "Payout has not been fully claimed");

            // Transfer the NFT from the user to the contract
            bondNft.transferFrom(msg.sender, address(this), tokenId);

            totalPayouts[msg.sender] += bond.payout;
            bondsDeposited[msg.sender].add(tokenId);
            
            unchecked {
                ++i;
            }
        }
    }

    function withdrawNfts(uint256[] calldata tokenIds) external {

        EnumerableSet.UintSet storage depositedTokens = bondsDeposited[msg.sender];

        for (uint256 i = 0; i < tokenIds.length;) {
            uint256 tokenId = tokenIds[i];
            require(depositedTokens.remove(tokenId), "Token not deposited");

            IBondNft.Bond memory bond = bondNftIBond.getBondData(tokenId);
            totalPayouts[msg.sender] -= bond.payout;

            // Transfer the NFT back to the owner (assuming ERC721)
            bondNft.transferFrom(address(this), msg.sender, tokenId);

            unchecked {
                ++i;
            }

        }
    }

    function getDepositedTokens(address account) external view returns (uint256[] memory) {

        uint256[] memory tokens = new uint256[](bondsDeposited[account].length());

        for (uint256 i = 0; i < bondsDeposited[account].length();) {
            tokens[i] = bondsDeposited[account].at(i);

            unchecked {
                ++i;
            }
        }
        return tokens;
    }
}
