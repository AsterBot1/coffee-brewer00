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
