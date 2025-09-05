// SPDX-License-Identifier: Apache-2.0
// Pyth Contracts (last updated commit cfa52f5) (target_chains/ethereum/sdk/solidity/Math.sol)
// Source: https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/sdk/solidity/PythUtils.sol

// Note: We only copy the subset of the library methods that we need

pragma solidity 0.8.27;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

library PythUtils {
    error NegativeInputPrice();
    error InvalidInputExpo();
    error ExponentOverflow();
    error CombinedPriceOverflow();

    /// @notice Converts a Pyth price to a uint256 with a target number of decimals
    /// @param price The Pyth price
    /// @param expo The Pyth price exponent
    /// @param targetDecimals The target number of decimals
    /// @return The price as a uint256
    /// @dev Function will lose precision if targetDecimals is less than the Pyth price decimals.
    /// This method will truncate any digits that cannot be represented by the targetDecimals.
    /// e.g. If the price is 0.000123 and the targetDecimals is 2, the result will be 0
    /// This function will revert with PythErrors.ExponentOverflow if the combined exponent (targetDecimals + expo) is greater than 58 or less than -58.
    /// Assuming the combined exponent is within bounds, this function will work for full range of int64 prices.
    /// The result of the computation is rounded down. In particular, if the result is < 1 in the delta exponent, it will be rounded to 0
    function convertToUint(
        int64 price,
        int32 expo,
        uint8 targetDecimals
    ) internal pure returns (uint256) {
        if (price < 0) {
            revert NegativeInputPrice();
        }
        if (expo < -255) {
            revert InvalidInputExpo();
        }

        // If targetDecimals is 6, we want to multiply the final price by 10 ** -6
        // So the delta exponent is targetDecimals + currentExpo
        int32 deltaExponent = int32(uint32(targetDecimals)) + expo;

        // Bounds check: prevent overflow/underflow with base 10 exponentiation
        // Calculation: 10 ** n <= (2 ** 256 - 63) - 1
        //              n <= log10((2 ** 193) - 1)
        //              n <= 58.2
        if (deltaExponent > 58 || deltaExponent < -58)
            revert ExponentOverflow();

        // We can safely cast the price to uint256 because the above condition will revert if the price is negative
        uint256 unsignedPrice = uint256(uint64(price));

        if (deltaExponent > 0) {
            (bool success, uint256 result) = Math.tryMul(
                unsignedPrice,
                10 ** uint32(deltaExponent)
            );
            // This condition is unreachable since we validated deltaExponent bounds above.
            // But keeping it here for safety.
            if (!success) {
                revert CombinedPriceOverflow();
            }
            return result;
        } else {
            (bool success, uint256 result) = Math.tryDiv(
                unsignedPrice,
                10 ** uint(SignedMath.abs(deltaExponent))
            );
            // This condition is unreachable since we validated deltaExponent bounds above.
            // But keeping it here for safety.
            if (!success) {
                revert CombinedPriceOverflow();
            }
            return result;
        }
    }
}
