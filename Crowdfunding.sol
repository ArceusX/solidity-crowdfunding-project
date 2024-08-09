// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Crowdfunding
 * @dev Implement Kickstarter && GoFundMe features
 * @custom:dev-run-script Crowdfunding.sol
 */

contract Crowdfunding {
    address public creator;

    // Goal set by creator. Affects outcome of only Kickstarter campaigns
    uint256 public goal;

    // Closing datetime computed as (block.timestamp + duration)
    uint256 public deadline;

    bool isKickstarter;

    // Default set to 500 Wei (~$1.50). Donation of less than this amount is refused
    uint256 public minDonation = 500;

    // Balance that crownfunder can cashout. For Kickstarter campaigns, totalRaised 
    // must meet goal metric to cashout; else, donors can requestRefund 
    uint256 public totalRaised;

    event Launch(
        address indexed creator,
        uint goal,
        uint start,
        uint end,
        bool isKickstarter
    );

    event Cashout(
        address indexed creator,
        uint goal,
        uint deadline,
        uint cashedDate,
        bool isKickstarter,
        uint paid
    );

    struct Tier {
        uint256 minAmount;
        string  reward;
    }
    Tier[] tiers;

    // {donor: donationTotal}. Use to conduct refunds
    mapping(address => uint256) public donations;

    // Constructor accepts only literals so 2000000000000000000 rather than 2 ether or 2 * 10**18
    constructor(uint256 _goal, uint256 durationInMinutes, bool _isKickstarter) {
        creator = msg.sender;
        goal = _goal;
        deadline = block.timestamp + 60 * durationInMinutes;
        isKickstarter = _isKickstarter;

        emit Launch(creator, goal, block.timestamp, deadline, isKickstarter);
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "To call this function, you must be the creator/crowdfunder.");
        _;
    }

    modifier onlyDonor() {
        require(
            donations[msg.sender] > 0, "To call this function, you must have donated.");
        _;
    }

    // For Kickstarer project, add tier, with that minimum [amount] and [reward].
    // Require new tier's minAmount > previously added tier's so each higher tier  
    // requires progressively larger donations
    function addTier(uint256 amount, string memory reward) public onlyCreator {
        require(isKickstarter, "GoFundMe projects do not have tiers and rewards. Denied.");
        require(block.timestamp < deadline, "The deadline for this campaign is past. Denied");

        require(amount >= minDonation,
        string(abi.encodePacked(
            "All tiers must have minimum donation amount of ", minDonation, " wei."))
        );

        require ((tiers.length == 0) || (amount > tiers[tiers.length - 1].minAmount), 
                "Each new tier must require progressively larger minimum donation.");

        tiers.push(Tier(amount, reward));
    }

    function getTiers() public view returns (Tier[] memory) {
        return tiers;
    }

    // View amount in contract that creator can cashout at campaign's end
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    // View time remaining until campaign's end as string "min_ m sec_"
    function countdown() public view  returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    function donate() public payable {
        require(block.timestamp < deadline, "The deadline for this campaign is past.");

        // Stops creator bypassing requirement that goal is reached to access cashout
        require(msg.sender != creator, "Cannot donate to your own campaign. Denied.");
        
        require(
            msg.value >= minDonation,
            string(abi.encodePacked("The minimum donation is ", minDonation, " wei. Donate more!"))
        );

        // Tally donation for that donor and for total
        donations[msg.sender] += msg.value;
        totalRaised += msg.value;
    }

    // Donor to get [amount] paid back to them
    // Allowed only if deadline is not past or goal is not met for Kickstarter campaign
    function requestRefund(uint256 amount) public onlyDonor {
        require(block.timestamp < deadline || (isKickstarter && (totalRaised < goal)), 
        "Can refund donation only if deadline is not past or goal is not met for Kickstarter campaign");

        require(donations[msg.sender] >= amount, "Cannot refund an amount more than your donation. Denied.");

        // On refund, zeroing donation record prevents double-spending
        payable(msg.sender).transfer(amount);
        totalRaised -= amount;
        donations[msg.sender] -= amount;
    }

    // Overloaded: Donor to request complete refund if no amount is specified
    function requestRefund() public onlyDonor {
        requestRefund(donations[msg.sender]);
    }

    // Creator should cashout at campaign's end. If goal is met, pay to creator from balance.
    // If isKickstarter and goal is not met, each donor should request refund
    function cashout() public onlyCreator {
        require(block.timestamp >= deadline,
        "Can cashout funds only after deadline is past. Denied");

        require(!isKickstarter || (totalRaised >= goal),
        "For Kickstarter campaign, can only cashout only if goal is met. Denied.");

        require(address(this).balance >= totalRaised, 
        "This contract has already been cashouted. Denied");

        payable(creator).transfer(address(this).balance);

        uint paid = (!isKickstarter || totalRaised >= goal) ? totalRaised : 0;

        emit Cashout(creator, goal, deadline, block.timestamp, isKickstarter, paid);
    }


    // Donor to view what rewards they earned based on their donation total
    function viewReward() public view onlyDonor returns (string memory) {
        require(block.timestamp > deadline,
        "Expect to get your reward only after the campaign has ended.");

        string memory rewards;

        if (isKickstarter) {
            
            require(totalRaised >= goal,
            "This Kickstarter campaign failed to meet its goal. You should request a refund.");

        	rewards = "Thanks";
            for (uint256 i = 0; i < tiers.length; i++) {
                if (donations[msg.sender] >= tiers[i].minAmount) {
                    rewards = string(abi.encodePacked(rewards, ". ", tiers[i].reward));
                }
            }
        }
        else {
            rewards = "Helping another person is its own reward.";
        }

        return rewards;
    }
}
