// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
  basic assumptions:
  - old destiny presale contract is unused just keep for legacy functions
  - every blacklisted user is a bot who should not be able to claim
*/

contract DestinySale {
    function dev() public view returns( address ) {}
    function sold() public view returns( uint ) {}
    function invested( address addr ) public view returns( uint ) {}
}

contract DestinySaleNew is Ownable {
    using SafeERC20 for ERC20;
    using Address for address;

    uint constant BUSDdecimals = 10 ** 18;
    uint constant FTLdecimals = 10 ** 9;
    uint public constant MAX_SOLD = 70000 * FTLdecimals;
    uint public constant PRICE = 7 * BUSDdecimals / FTLdecimals ; // 7 busd per token
    uint public constant MIN_PRESALE_PER_ACCOUNT = 10 * FTLdecimals;
    uint public constant MAX_PRESALE_PER_ACCOUNT = 100 * FTLdecimals;
    //address public constant OLD_CONTRACT_ADDRESS = 0x8301f2213c0eed49a7e28ae4c3e91722919b8b47; // Destiny sale OLD legacy contract

    address public dev;
    ERC20 BUSD;
    //DestinySale oldContract;

    uint public sold;
    address public FTL;
    bool canClaim;
    bool privateSale;
    mapping( address => uint256 ) public invested;
    mapping( address => bool ) public claimed;
    mapping( address => bool ) public approvedBuyers;
    //mapping( address => bool ) public blacklisted;

    constructor() {
        BUSD = ERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7); // testnet BUSD
        //oldContract = DestinySale(OLD_CONTRACT_ADDRESS);
        dev = 0xa34a0247Ee187eeB497d7591381777EEA860D680; 
        //sold = oldContract.sold();
    }


    modifier onlyEOA() {
        require(msg.sender == tx.origin, "!EOA");
        _;
    }

    /* approving buyers into new whitelist */

    function _approveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = true;
        return approvedBuyers[newBuyer_];
    }

    function approveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _approveBuyer( newBuyer_ );
    }

    function approveBuyers( address[] calldata newBuyers_ ) external onlyOwner() returns ( uint256 ) {
        for( uint256 iteration_ = 0; newBuyers_.length > iteration_; iteration_++ ) {
            _approveBuyer( newBuyers_[iteration_] );
        }
        return newBuyers_.length;
    }

    function _deapproveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = false;
        return approvedBuyers[newBuyer_];
    }

    function deapproveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _deapproveBuyer(newBuyer_);
    }

    /* blacklisting old buyers who shouldn't be able to claim; subtract contrib from sold allocation */
/*
    function _blacklistBuyer( address badBuyer_ ) internal onlyOwner() returns ( bool ) {
        if (!blacklisted[badBuyer_]) {
            sold -= oldContract.invested(badBuyer_);
        }
        blacklisted[badBuyer_] = true;
        return blacklisted[badBuyer_];
    }

    function blacklistBuyer( address badBuyer_ ) external onlyOwner() returns ( bool ) {
        return _blacklistBuyer( badBuyer_ );
    }

    function blacklistBuyers ( address[] calldata badBuyers_ ) external onlyOwner() returns ( uint256 ) {
        for ( uint256 iteration_ = 0; badBuyers_.length > iteration_; iteration_++ ) {
            _blacklistBuyer( badBuyers_[iteration_] );
        }
        return badBuyers_.length;
    }*/

    /* allow non-blacklisted users to buy FTL */

    function amountBuyable(address buyer) public view returns (uint256) {
        uint256 max;
        if ( approvedBuyers[buyer] && privateSale ) {
            max = MAX_PRESALE_PER_ACCOUNT;
        }
        return max - invested[buyer];
    }

    function buyFTL(uint256 amount) public onlyEOA {
        require(sold < MAX_SOLD, "sold out");
        require(sold + amount < MAX_SOLD, "not enough remaining");
        require(amount <= amountBuyable(msg.sender), "amount exceeds buyable amount");
        require(amount + invested[msg.sender] >= MIN_PRESALE_PER_ACCOUNT, "amount is not sufficient");
        //require(oldContract.invested(msg.sender) == 0, "investor in previous LBE");
        BUSD.safeTransferFrom( msg.sender, address(this), amount * PRICE  );
        invested[msg.sender] += amount;
        sold += amount;
    }

    // set FTL token address and activate claiming
    function setClaimingActive(address ftl) public {
        require(msg.sender == dev, "!dev");
        FTL = ftl;
        canClaim = true;
    }

    // claim FTL allocation based on old + new invested amounts
    function claimFTL() public onlyEOA {
        require(canClaim, "cannot claim yet");
        require(!claimed[msg.sender], "already claimed");
        //require(!blacklisted[msg.sender], "blacklisted");
        if ( invested[msg.sender] > 0 ) {
            ERC20(FTL).transfer(msg.sender, invested[msg.sender]);
        }/* else if ( oldContract.invested(msg.sender) > 0 ) {
            ERC20(FTL).transfer(msg.sender, oldContract.invested(msg.sender));
        }*/
        claimed[msg.sender] = true;
    }

    // token withdrawal by dev
    function withdraw(address _token) public {
        require(msg.sender == dev, "!dev");
        uint b = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(dev,b);
    }

    // manual activation of whitelisted sales
    function activatePrivateSale() public {
        require(msg.sender == dev, "!dev");
        privateSale = true;
    }

    // manual deactivation of whitelisted sales
    function deactivatePrivateSale() public {
        require(msg.sender == dev, "!dev");
        privateSale = false;
    }

    function setSold(uint _soldAmount) public onlyOwner {
        sold = _soldAmount;
    }
}