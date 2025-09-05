// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {DephaserJPY} from "@src/DephaserJPY.sol";
import {UsdcDepositManager} from "@src/UsdcDepositManager.sol";
import {UPGRADER_ROLE, OPERATOR_ROLE} from "@src/constants/RoleConstants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20PermitMinimal} from "@src/interfaces/external/IERC20PermitMinimal.sol";

contract DeployUsdcDepositManager is Script {
    // Base mainnet addresses
    address private constant USDC_USD_PRICE_FEED =
        0x7e860098F58bBFC8648a4311b374B1D669a2bc6B; // chainlink usdc/usd
    address private constant PYTH_ADDRESS =
        0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a; // pyth
    bytes32 private constant USD_JPY_PRICE_ID =
        0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52; // pyth usd/jpy price id
    uint256 private constant VALID_TIME_PERIOD = 1800; // pyth valid time period

    address private constant DEPOSIT_TOKEN =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
    address private constant AAVE_POOL =
        0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // aave pool mainnet base

    address private constant DEFAULT_ADMIN =
        0xBDD551c66fD1C04B289f9faCAD9CF1D62745a0Fe; // change this to your address
    address private constant OPERATOR =
        0xBDD551c66fD1C04B289f9faCAD9CF1D62745a0Fe; // change this to your address

    DephaserJPY public jpytToken;
    UsdcDepositManager public depositManager;

    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        deployJpytToken();
        deployUsdcDepositManager();
        setupRoles();

        vm.stopBroadcast();
    }

    function deployJpytToken() private {
        jpytToken = new DephaserJPY(DEFAULT_ADMIN);
        console2.log("JpytToken deployed at:", address(jpytToken));
    }

    function deployUsdcDepositManager() private {
        address managerAddress = Upgrades.deployUUPSProxy(
            "UsdcDepositManager.sol",
            abi.encodeCall(
                UsdcDepositManager.initialize,
                (
                    DEFAULT_ADMIN,
                    OPERATOR,
                    AAVE_POOL,
                    PYTH_ADDRESS,
                    USD_JPY_PRICE_ID,
                    VALID_TIME_PERIOD,
                    DEPOSIT_TOKEN,
                    USDC_USD_PRICE_FEED,
                    address(jpytToken),
                    10 // initialCooldownBlocks
                )
            )
        );

        depositManager = UsdcDepositManager(managerAddress);
        console2.log(
            "UsdcDepositManager deployed at:",
            address(depositManager)
        );
    }

    function setupRoles() private {
        jpytToken.grantRole(jpytToken.MINTER_ROLE(), address(depositManager));
        jpytToken.grantRole(jpytToken.BURNER_ROLE(), address(depositManager));
        depositManager.grantRole(UPGRADER_ROLE, DEFAULT_ADMIN);

        console2.log("Roles set up successfully");
    }
}
