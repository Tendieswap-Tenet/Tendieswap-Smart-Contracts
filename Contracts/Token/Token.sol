pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "Token/ITendies.sol";

contract Tendies is ITendies, ERC20, Ownable, ReentrancyGuard {
    uint256 private _totalSupply;
    uint256 public constant INITIAL_SUPPLY = 2_300_000 * (10**18);
    uint256 public constant MAX_SUPPLY = 100_000_000 * (10**18);
    uint256[] public emissions;
    uint256[] public emissionsCap;
    address[] public rewardAddresses;
    uint256[] public teamEmissions;
    uint256[] public teamEmissionsCap;
    address[] public teamAddresses;
    address public marketingAddress;
    uint256 public marketingEmissions;

    constructor(address _dao, address _tenet, address _marketing) ERC20("Tendies", "TENDIES") {
        mint(msg.sender, INITIAL_SUPPLY);
        //Liq 1mil, Marketing .5mil, Team/Advisors .8mil -> Total 2.3mil
        emissions = [0,0,0,0];
        rewardAddresses = [_dao, _dao, _dao, _dao];
        emissionsCap = [35_000_000 * (10**18), 10_000_000 * (10**18), 10_000_000 * (10**18), 5_000_000 * (10**18)];
        //Bonding 35mil, Staking 10mil, Farming 10mil, Bonding Rewards 5mil -> Total 60mil
        teamEmissions = [0,0,0,0,0];
        teamAddresses = [_dao, _tenet, _dao, _dao, _dao];
        teamEmissionsCap = [20_000_000 * (10**18), 5_000_000 * (10**18), 5_000_000 * (10**18), 2_500_000 * (10**18), 2_500_000 * (10**18)];
        //Team 20mil, Tenet Foundation 5mil, Tendies DAO 5mil, Launchpad 2.5mil, Listings 2.5mil -> Total 35mil
        marketingAddress = _marketing;
        marketingEmissions = 0;
        //Marketing 2.7mil -> Total 2.7mil
        //TOTAL SUPPLY 100 MIL
    }

    function setRewardAddresses(uint256 rewardIndex, address newAddress) external onlyOwner {
        require(rewardIndex < rewardAddresses.length, "Invalid team index");

        rewardAddresses[rewardIndex] = newAddress;
    }

    function setTeamAddresses(uint256 teamIndex, address newAddress) external  {
        require(teamIndex < teamAddresses.length, "Invalid team index");
        require(msg.sender == teamAddresses[teamIndex], "Caller is not authorized");

        teamAddresses[teamIndex] = newAddress;
    }

    function changeMarketingAddress(address newAddress) external {
        require(msg.sender == marketingAddress, "Caller is not the current marketing address");

        marketingAddress = newAddress;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function mint(address recipient, uint256 amount) internal {
        require(_totalSupply + amount < MAX_SUPPLY, "MAX SUPPLY");
        _totalSupply += amount;
        _mint(recipient, amount);
    }   

    function mintMarketing() external onlyOwner {
        uint256 emitted = emissions[0];
        uint256 decimals = decimals();

        if (emitted > 10_000_000 * (10**decimals) && marketingEmissions == 0) {
            mint(marketingAddress, 1_000_000 * (10**decimals));
            marketingEmissions = 1_000_000 * (10**decimals);
            
        }

        if (emitted > 20_000_000 * (10**decimals) && marketingEmissions == 1_000_000 * (10**decimals)) {
            mint(marketingAddress, 1_700_000 * (10**decimals));
            marketingEmissions = 2_700_000 * (10**decimals);
        }
    }

    function mintRewards(uint256 rewardIndex, uint256 amount, address recipient) external nonReentrant {
        require(rewardIndex < rewardAddresses.length, "Index is not authorized");
        require(msg.sender == rewardAddresses[rewardIndex], "Caller is not authorized");
        require(emissions[rewardIndex] + amount <= emissionsCap[rewardIndex], "Exceeded emissions cap");

        mint(recipient, amount);
        emissions[rewardIndex] += amount;
    }

    function mintTeam(uint256 teamIndex, uint256 amount, address recipient) external {
        require(teamIndex < teamAddresses.length, "Index is not authorized");
        require(msg.sender == teamAddresses[teamIndex], "Caller is not authorized");
        require(teamEmissions[teamIndex] + amount <= teamEmissionsCap[teamIndex], "Exceeded team emissions cap");

        mint(recipient, amount);
        teamEmissions[teamIndex] += amount;
    }
}



