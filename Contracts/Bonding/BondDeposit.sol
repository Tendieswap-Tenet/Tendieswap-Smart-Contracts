// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "Bonding/IBondNft.sol";
import "Bonding/IVestingCurve.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BondDeposit is Ownable, ReentrancyGuard {


    /* ======== STRUCTS ======== */

    struct BondCreationDetails {
        address payoutToken;
        address principalToken;
        address dao;
        address vestingCurve;
        address bondNft;
    }

    struct BondTerms {
        uint256 controlVariable;
        uint256 vestingTerm;
        uint256 minimumPrice;
        uint256 maxPayout;
        uint256 maxDebt;
        uint256 maxTotalPayout;
    }

    // Info for incremental adjustments to control variable 
    struct Adjust {
        uint256 rate; // increment
        uint256 target; // BCV when adjustment finished
        uint256 buffer; // minimum length (in seconds) between adjustments
        uint256 lastAdjustmentTimestamp; // timestamp when last adjustment made
    }

    /* ======== STATE VARIABLES ======== */

    IERC20 public payoutToken; // token paid for principal
    IERC20 public principalToken; // inflow token
    address public DAO; // change feeTo address
    IBondNft public bondNft; //Address of BondNFT ERC721
    IVestingCurve public vestingCurve; //Address of vesting curve

    uint256 public totalPrincipalBonded; //TotalBonded
    uint256 public totalPayoutGiven; //TotalRewards

    BondTerms public terms; // stores terms for new bills
    Adjust public adjustment; // stores adjustment to BCV data


    uint256 public totalDebt; // total value of outstanding bills; used for pricing
    uint256 public lastDecay; // reference block for debt decay


    /* ======== INITIALIZATION ======== */

    constructor(
    ) {

    BondCreationDetails memory _bondCreationDetails = BondCreationDetails(
        0x0260F440AEa04a1690aB183Dd63C5596d66A9a43,
        0xEc9fD175dFbf5Ea5a5dA64436E41d3736a74C04F,
        0x9584329601571a4Dd2BdC5d47DE39524445C95d7,
        0x90046009072c41c8Bb85ee018524e30A7352DD7C,
        0x973BD71B3a9C63BA56ea845923Bf822DC9694c81
    );

    BondTerms memory _bondTerms = BondTerms(
        800,
        432000,
        184800000000000000,
        1000,
        50000000000000000000000,
        35000000000000000000000000
    );
        require(_bondCreationDetails.payoutToken != address(0), "payoutToken cannot be zero");
        payoutToken = IERC20(_bondCreationDetails.payoutToken);
        require(_bondCreationDetails.principalToken != address(0), "principalToken cannot be zero");
        principalToken = IERC20(_bondCreationDetails.principalToken);
        uint256 currentTimestamp = block.timestamp;
        require(_bondCreationDetails.vestingCurve != address(0), "vestingCurve cannot be zero");
        vestingCurve = IVestingCurve(_bondCreationDetails.vestingCurve);

        require(_bondCreationDetails.dao != address(0), "DAO cannot be zero");
        DAO = _bondCreationDetails.dao;

        require(_bondCreationDetails.bondNft != address(0), "bondNft cannot be zero");
        bondNft = IBondNft(_bondCreationDetails.bondNft);


        // Check and set billTerms
        require(currentDebt() == 0, "Debt must be 0");
        require(_bondTerms.vestingTerm >= 129600, "Vesting must be >= 36 hours");
        require(_bondTerms.maxPayout <= 1000, "Payout cannot be above 1 percent");
        require(_bondTerms.controlVariable > 0, "CV must be above 1");

        terms = _bondTerms;

        totalDebt = 0;
        lastDecay = currentTimestamp;

    }
    
    /* ======== OWNER FUNCTIONS ======== */

    /**
     *  @notice set parameters for new bills
     *  @param _parameter PARAMETER
     *  @param _input uint
     */
    function setBondTerms(uint _parameter, uint256 _input)
        external
        onlyOwner
    {
        if (_parameter == 0) {
            // 0
            require(_input >= 129600, "Vesting must be >= 36 hours");
            terms.vestingTerm = _input;
        } else if (_parameter == 1) {
            // 1
            require(_input <= 1000, "Payout cannot be above 1 percent");
            terms.maxPayout = _input;
        } else if (_parameter == 2) {
            // 2
            terms.maxDebt = _input;
        } else if (_parameter == 3) {
            // 3
            terms.minimumPrice = _input;
        } else if (_parameter == 4) {
            // 4
            require(_input >= totalPayoutGiven, "maxTotalPayout cannot be below totalPayoutGiven");
            terms.maxTotalPayout = _input;
        }

    }

    /**
     *  @notice helper function to view the maxTotalPayout
     *  @dev backward compatibility for V1
     *  @return uint256 max amount of payoutTokens to offer
     */
    function getMaxTotalPayout() external view returns (uint256) {
        return terms.maxTotalPayout;
    }

    /**
     *  @notice set the maxTotalPayout of payoutTokens
     *  @param _maxTotalPayout uint256 max amount of payoutTokens to offer
     */
    function setMaxTotalPayout(uint256 _maxTotalPayout) external onlyOwner {
        require(_maxTotalPayout >= totalPayoutGiven, "maxTotalPayout <= totalPayout");
        terms.maxTotalPayout = _maxTotalPayout;
    }

    /**
     *  @notice set control variable adjustment
     *  @param _rate Amount to add to/subtract from the BCV to reach the target on each adjustment
     *  @param _target Final BCV to be adjusted to
     *  @param _buffer Time in seconds which must pass before the next incremental adjustment
     */
    function setAdjustment(
        uint256 _rate,
        uint256 _target,
        uint256 _buffer
    ) external onlyOwner {
        require(_target > 0, "Target must be above 0");
        /// @dev This is allowing a max price change of 3% per adjustment
        uint256 maxRate = (terms.controlVariable * 30) / 1000;
        if(maxRate == 0) maxRate = 1;
        require(
            _rate <= maxRate,
            "Increment too large"
        );

        adjustment = Adjust({
            rate: _rate,
            target: _target,
            buffer: _buffer,
            /// @dev Subtracting _buffer to be able to run adjustment on next tx
            lastAdjustmentTimestamp: block.timestamp - _buffer
        });

    }

    /**
     *  @notice change address of Treasury
     *  @param _feeTo address
     */
    function changeFeeTo(address _feeTo) external {
        require(msg.sender == DAO, "Only DAO");
        require(_feeTo != address(0), "Cannot be address(0)");
        DAO = _feeTo;
    }

    /* ======== USER FUNCTIONS ======== */


    function deposit(
        uint256 _amount,
        uint256 _maxPrice
 
    ) external returns (uint256 payout, uint256 bondId) {

        _decayDebt();
        uint256 truePrice = _bondPrice();
        require(_maxPrice >= truePrice, "Slippage more than max price"); // slippage protection
        // Calculate payout and fee
        uint256 depositAmount = _amount;
        payout = payoutFor(_amount); 

        // Increase totalDebt by amount deposited
        totalDebt += _amount;
        require(totalDebt <= terms.maxDebt, "Max capacity reached");

        require(payout >= 10 ** 18 / 1000, "Bill too small" ); // must be > 0.01 payout token ( underflow protection )
        require(payout <= maxPayout(), "Bill too large"); // size protection because there is no slippage
        totalPayoutGiven += payout; // total payout increased

        require(totalPayoutGiven <= terms.maxTotalPayout, "Max total payout exceeded");
        totalPrincipalBonded += depositAmount; // total billed increased

        // Transfer principal token to BillContract
        principalToken.transferFrom(msg.sender, DAO, _amount);

        IBondNft.Bond memory _info = IBondNft.Bond({
            payout: payout,
            payoutClaimed: 0,
            vestingTerm: terms.vestingTerm,
            vestingStartTimestamp: block.timestamp,
            lastClaimTimestamp: block.timestamp,
            truePricePaid: truePrice
        });

        // Create BillNFT
        bondId = bondNft.mintBond( msg.sender, _info);

        // Adjust control variable
        _adjust();
  
        return (payout, bondId);
    }

    /* ======== INTERNAL HELPER FUNCTIONS ======== */

    /**
     *  @notice makes incremental adjustment to control variable
     */
    function _adjust() internal {
        uint256 timestampCanAdjust = adjustment.lastAdjustmentTimestamp + adjustment.buffer;
        if(adjustment.rate != 0 && block.timestamp >= timestampCanAdjust) {
            
            uint256 bcv = terms.controlVariable;
            uint256 rate = adjustment.rate;
            uint256 target = adjustment.target;
            if(bcv > target) {
                // Pulling bcv DOWN to target
                uint256 diff = bcv - target;
                if(diff > rate) {
                    bcv -= rate;
                } else {
                    bcv = target;
                    adjustment.rate = 0;
                }
            } else {
                // Pulling bcv UP to target
                uint256 diff = target - bcv;
                if(diff > rate) {
                    bcv += rate;
                } else {
                    bcv = target;
                    adjustment.rate = 0;
                }
            }
            adjustment.lastAdjustmentTimestamp = block.timestamp;
            terms.controlVariable = bcv;

        }
    }

    /**
     *  @notice reduce total debt
     */
    function _decayDebt() internal {
        uint256 decay = debtDecay();
        if (decay >= totalDebt) {
            totalDebt = 0;
        } else {
            totalDebt -= decay;
        }
        lastDecay = block.timestamp;
    }

    /**
     *  @notice calculate current bill price and remove floor if above
     *  @return price_ uint Price is denominated with 18 decimals
     */
    function _bondPrice() internal returns (uint256 price_) {
        price_ = bondPrice();
        if (price_ > terms.minimumPrice && terms.minimumPrice != 0) {
            /// @dev minimumPrice is set to zero as it assumes that market equilibrium has been found at this point.
            /// Moving forward the price should find balance through natural market forces such as demand, arbitrage and others
            terms.minimumPrice = 0;
        } 
    }

    /* ======== VIEW FUNCTIONS ======== */


    /**
     *  @notice calculate current bill premium
     *  @return price_ uint Price is denominated using 18 decimals
     */
    function bondPrice() public view returns (uint256 price_) {
        /// @dev 1e2 * 1e(principalTokenDecimals) * 1e16 / 1e(principalTokenDecimals) = 1e18
        if ((terms.controlVariable * debtRatio() * 1e16 / 10 ** 18) < terms.minimumPrice) {
            price_ = terms.minimumPrice;
        } else {
            price_ = terms.controlVariable * debtRatio() * 1e16 / 10 ** 18;
        }
    }

    /**
     *  @notice determine maximum bill size
     *  @return uint
     */
    function maxPayout() public view returns (uint256) {
        return (payoutToken.totalSupply() * terms.maxPayout) / 100000;
    }


    function payoutFor(uint256 _amount) public view returns (uint256 _payout) {

            // Using amount of principalTokens - _fee, find the amount of payout tokens by dividing by billPrice.
            _payout = _amount * 1e18 / bondPrice();
    }

    /**
     *  @notice calculate current ratio of debt to payout token supply
     *  @notice protocols using this system should be careful when quickly adding large %s to total supply
     *  @return debtRatio_ uint debtRatio denominated in principalToken decimals
     */
    function debtRatio() public view returns (uint256 debtRatio_) {
            debtRatio_ = currentDebt() * 10 ** 18 / payoutToken.totalSupply();
    }

    /**
     *  @notice calculate debt factoring in decay
     *  @return uint currentDebt denominated in principalToken decimals
     */
    function currentDebt() public view returns (uint256) {
        if (totalDebt > debtDecay()) {
             return totalDebt - debtDecay();
        } else {
            return 0;
        }
    }

    /**
     *  @notice amount to decay total debt by
     *  @return decay_ uint debtDecay denominated in principalToken decimals
     */
    function debtDecay() public view returns (uint256 decay_) {
        if (terms.vestingTerm == 0) {
            decay_ = totalDebt;
        } else {
            uint256 timestampSinceLast = block.timestamp - lastDecay;
            decay_ = (totalDebt * timestampSinceLast) / terms.vestingTerm;

            if (decay_ > totalDebt) {
                decay_ = totalDebt;
            }
        }
    }
    

}