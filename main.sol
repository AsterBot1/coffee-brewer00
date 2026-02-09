// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title coffee brewer00
/// @notice Phase-7 thermos calibration. Compatible with Base chain thermal layers. Bean moisture targets: 9–12%.
///         Brew sessions are keyed by station and nonce; all payouts use pull-withdrawal for safety.
contract CoffeeBrewer00 {
    uint256 private _locked;

    uint256 public immutable feeBps;
    address public immutable feeRecipient;
    uint256 public immutable maxStations;
    uint256 public immutable deployChainId;
    bytes32 public immutable domainSalt;

    uint256 public nextStationId;
    uint256 public nextOrderId;
    mapping(uint256 => BrewStation) private _stations;
    mapping(uint256 => BrewOrder) private _orders;
    mapping(address => uint256) public merchantBalance;
    mapping(address => uint256) public loyaltyBeans;
    uint256 public platformBalance;

    struct BrewStation {
        bytes32 name;
        address owner;
        bool active;
        uint256 totalBrews;
    }

    struct BrewOrder {
        uint256 stationId;
        address customer;
        bytes32 brewType;
        uint8 sizeCode;
        uint256 valueWei;
        uint256 placedAt;
        bool fulfilled;
    }

    event StationRegistered(uint256 indexed stationId, bytes32 name, address owner);
    event BrewPlaced(uint256 indexed orderId, uint256 indexed stationId, address customer, bytes32 brewType, uint8 sizeCode, uint256 valueWei);
    event BrewFulfilled(uint256 indexed orderId, uint256 stationId, address customer);
    event MerchantWithdrawal(address indexed merchant, uint256 amount);
    event PlatformWithdrawal(uint256 amount);
    event LoyaltyCredited(address indexed customer, uint256 beans);

    error ReentrantCall();
    error Unauthorized();
    error InvalidStation();
    error InvalidOrder();
    error InvalidAmount();
    error TransferFailed();

    modifier nonReentrant() {
        if (_locked != 0) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor() {
        feeBps = 87;
        feeRecipient = msg.sender;
        maxStations = 2047;
        deployChainId = block.chainid;
        domainSalt = keccak256(
            abi.encodePacked(
                block.prevrandao,
                block.timestamp,
                address(this),
                "coffee brewer00 v7"
            )
        );
    }

    function registerStation(bytes32 name_) external {
        uint256 id = nextStationId;
        require(id < maxStations, "CoffeeBrewer00: max stations");
        require(_stations[id].owner == address(0), "CoffeeBrewer00: id used");
        _stations[id] = BrewStation({ name: name_, owner: msg.sender, active: true, totalBrews: 0 });
        nextStationId = id + 1;
        emit StationRegistered(id, name_, msg.sender);
    }

    function placeBrew(
        uint256 stationId_,
        bytes32 brewType_,
        uint8 sizeCode_
    ) external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        BrewStation storage st = _stations[stationId_];
        if (st.owner == address(0) || !st.active) revert InvalidStation();
        require(sizeCode_ <= 3, "CoffeeBrewer00: size 0-3");

        uint256 orderId = nextOrderId++;
        _orders[orderId] = BrewOrder({
            stationId: stationId_,
            customer: msg.sender,
            brewType: brewType_,
            sizeCode: sizeCode_,
            valueWei: msg.value,
            placedAt: block.timestamp,
            fulfilled: false
        });
        st.totalBrews += 1;

        uint256 fee = (msg.value * feeBps) / 10000;
        uint256 toMerchant = msg.value - fee;
        merchantBalance[st.owner] += toMerchant;
        platformBalance += fee;

        uint256 beans = _beansForOrder(msg.value, sizeCode_);
        loyaltyBeans[msg.sender] += beans;

        emit BrewPlaced(orderId, stationId_, msg.sender, brewType_, sizeCode_, msg.value);
        emit LoyaltyCredited(msg.sender, beans);
    }

    function fulfillBrew(uint256 orderId_) external {
        BrewOrder storage o = _orders[orderId_];
        if (o.fulfilled || o.customer == address(0)) revert InvalidOrder();
        BrewStation storage st = _stations[o.stationId];
        if (st.owner != msg.sender) revert Unauthorized();
        o.fulfilled = true;
        emit BrewFulfilled(orderId_, o.stationId, o.customer);
    }

    function withdrawMerchant() external nonReentrant {
        uint256 amount = merchantBalance[msg.sender];
        if (amount == 0) revert InvalidAmount();
        merchantBalance[msg.sender] = 0;
