// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract WishChain {
    struct Wish {
        string text;
        string status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => Wish[]) public userWishes;

    IERC20 public usdtToken;
    address public owner;
    uint256 public constant FEE = 1 * 10**6; // 1 USDT = 1,000,000 (6 decimals)

    event WishCreated(address indexed user, uint256 index, string text);
    event WishUpdated(address indexed user, uint256 index, string newText, string newStatus);
    event USDTWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _usdtAddress) {
        usdtToken = IERC20(_usdtAddress);
        owner = msg.sender;
    }

    function createWish(string memory _text) external {
        require(usdtToken.transferFrom(msg.sender, address(this), FEE), "Payment failed");

        Wish memory newWish = Wish({
            text: _text,
            status: "Still Dreaming",
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        userWishes[msg.sender].push(newWish);
        emit WishCreated(msg.sender, userWishes[msg.sender].length - 1, _text);
    }

    function updateWish(uint256 _index, string memory _newText, string memory _newStatus) external {
        require(_index < userWishes[msg.sender].length, "Wish not found");
        require(usdtToken.transferFrom(msg.sender, address(this), FEE), "Payment failed");

        Wish storage wish = userWishes[msg.sender][_index];
        wish.text = _newText;
        wish.status = _newStatus;
        wish.updatedAt = block.timestamp;

        emit WishUpdated(msg.sender, _index, _newText, _newStatus);
    }

    function getWish(uint256 _index) external view returns (Wish memory) {
        require(_index < userWishes[msg.sender].length, "Wish not found");
        return userWishes[msg.sender][_index];
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(usdtToken.balanceOf(address(this)) >= _amount, "Insufficient balance");
        require(usdtToken.transfer(owner, _amount), "Withdraw failed");
        emit USDTWithdrawn(owner, _amount);
    }

    function contractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
}
