// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Staking/ITendies.sol";
import "Staking/IBondVault.sol";

// import "@nomiclabs/buidler/console.sol";

// MasterChef is the master of Tendies. He can make Tendies and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CAKE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract TendieChef is Ownable {

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //å
        // We do some fancy math here. Basically, any point in time, the amount of CAKEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTendiesPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTendiesPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. CAKEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that Tendies distribution occurs.
        uint256 accTendiesPerShare; // Accumulated Tendies per share, times 1e12. See below.
        uint256 lpBalance; // For staking tokens.
    }

    // The Tendies TOKEN!
    ITendies public tendies;
    // Dev address.
    address public devaddr;
    // Tendies tokens created per block.
    uint256 public tendiesPerBlock;
    // Bond NFT Accumulator Contract
    IBondVault public bondVault;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Tendies mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ITendies _tendies,
        address _devaddr,
        uint256 _tendiesPerBlock,
        uint256 _startBlock,
        IBondVault _bondVault
    )  {
        tendies = _tendies;
        devaddr = _devaddr;
        tendiesPerBlock = _tendiesPerBlock;
        startBlock = _startBlock;
        bondVault = _bondVault;

        // staking pool
        poolInfo.push(PoolInfo({lpToken: IERC20(address(_tendies)), allocPoint: 1000, lastRewardBlock: startBlock, accTendiesPerShare: 0, lpBalance:0}));

        totalAllocPoint = 1000;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + (_allocPoint);
        poolInfo.push(
            PoolInfo({lpToken: _lpToken, allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accTendiesPerShare: 0, lpBalance:0})
        );
        updateStakingPool();
    }

    // Update the given pool's TENDIES allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint - prevAllocPoint + (_allocPoint);
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points + (poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points / (3);
            totalAllocPoint = totalAllocPoint - poolInfo[0].allocPoint + (points);
            poolInfo[0].allocPoint = points;
        }
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - (_from);
    }

    // View function to see pending TENDIES on frontend.
    function pendingTendies(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTendiesPerShare = pool.accTendiesPerShare;
        uint256 lpSupply = pool.lpBalance;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tendiesReward = multiplier * tendiesPerBlock * (pool.allocPoint) / (totalAllocPoint);
            accTendiesPerShare = accTendiesPerShare + (tendiesReward * (1e12) / (lpSupply));
        }
        return (user.amount * (accTendiesPerShare) / (1e12)) - (user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpBalance;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tendiesReward = multiplier * (tendiesPerBlock) * (pool.allocPoint) / (totalAllocPoint);
        if (tendies.emissions(1) + tendiesReward <= tendies.emissionsCap(1)) {
            tendies.mintRewards(1, tendiesReward, address(this));
            pool.accTendiesPerShare = pool.accTendiesPerShare + (tendiesReward * (1e12) / (lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for TENDIES allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = (user.amount * (pool.accTendiesPerShare) / (1e12)) - (user.rewardDebt);
            if (pending > 0) {
                safeTendiesTransfer(msg.sender, pending);
                //Percent is adjusted mul by 1000
                uint256 bondPercentAdjusted = bondVault.bondPayoutAmountDivSupply(msg.sender);
                //User Percent * 100 as multiplier, i.e. 1% gives 100% of pending as bonus
                uint256 bondBonus = (pending * bondPercentAdjusted) / 1000;
                if (bondBonus > 0 && (tendies.emissions(3) + bondBonus <= tendies.emissionsCap(3))) {
                    //Mint to user
                    tendies.mintRewards(3, bondBonus, msg.sender);
                }
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(msg.sender, address(this), _amount);
            poolInfo[_pid].lpBalance += _amount;
            user.amount = user.amount + (_amount);
        }
        user.rewardDebt = user.amount * (pool.accTendiesPerShare) / (1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = (user.amount * (pool.accTendiesPerShare) / (1e12)) - (user.rewardDebt);
        uint256 bondPercentAdjusted = bondVault.bondPayoutAmountDivSupply(msg.sender);

        if (pending > 0) {
            safeTendiesTransfer(msg.sender, pending);
            //User Percent * 100 as multiplier, i.e. 1% gives 100% of pending as bonus
            uint256 bondBonus = (pending * bondPercentAdjusted) / 1000;
            if (bondBonus > 0 && (tendies.emissions(3) + bondBonus <= tendies.emissionsCap(3))) {
                //Mint to user
                tendies.mintRewards(3, bondBonus, msg.sender);
            }

        }

        if (_amount > 0) {
            user.amount = user.amount - (_amount);
            //If bondedPayouts >= .5% total supply no withdrawal fee
            if (bondPercentAdjusted >= 500) {
                pool.lpToken.transfer( address(msg.sender), _amount);
                poolInfo[_pid].lpBalance -= _amount;
            } else {
                //Else 1% withdrawal fee
                pool.lpToken.transfer( devaddr, _amount / 100 );
                pool.lpToken.transfer( address(msg.sender), (_amount * 99) / 100);
                poolInfo[_pid].lpBalance -= _amount;
            }
        }

        user.rewardDebt = user.amount * (pool.accTendiesPerShare) / (1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        //Fee set here to prevent gamifying withdrawal
        pool.lpToken.transfer( devaddr, user.amount / 100 );
        pool.lpToken.transfer( address(msg.sender), (user.amount * 99) / 100);
        poolInfo[_pid].lpBalance -= user.amount;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe tendies transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safeTendiesTransfer(address _to, uint256 _amount) internal {
        uint256 tendiesBal = IERC20(address(tendies)).balanceOf(address(this)) - poolInfo[0].lpBalance;
        if (_amount > tendiesBal) {
            IERC20(address(tendies)).transfer(_to, tendiesBal);
        } else {
            IERC20(address(tendies)).transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}