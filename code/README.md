# Take Home Exercises

## Submission Overview

### Exercise A: OTC Swap

- **Solidity Code**: Provided in `contracts/OTC_Swap.sol`.
- **Test Cases**: Provided in `test/OTCswap.js`.
  1. **Successful Swap**: Ensure Alice and Bob can swap their tokens successfully.
  2. **Counterparty Restriction**: Verify that only the specified counterparty can execute the swap.
  3. **Expiry**: Test that the swap cannot be executed after the specified timeframe.
  4. **Partial Fulfillment**: Ensure the swap does not execute if the token amounts are not met exactly.

### Exercise C: Decentralized Marketplace

- **Solidity Code**: Provided in `contracts/Decentralized_Marketplace.sol`.
- **Test Cases**: Provided in `test/DecentralizedMarketplace.js`.
  1. **User Registration**: Test user registration with unique usernames.
  2. **Item Listing**: Verify that users can list items with correct attributes.
  3. **Item Purchase**: Ensure correct transfer of ownership and update item status upon purchase.
  4. **Item Retrieval**: Test retrieval of item details by ID.

## Project Setup

To set up the project, follow these steps:

### Prerequisites

- Node.js and npm (Node Package Manager) installed on your machine.
- Hardhat framework installed.

### Step-by-Step Setup

1. **Clone the Repository**

   ```bash
   git clone <repository-url>
   cd <repository-folder>
   ```

2. **Install Dependencies**

   ```bash
   npm install
   ```

3. **Compile the Smart Contracts**

   ```bash
   npx hardhat compile
   ```

4. **Run Tests**
   ```bash
   npx hardhat test
   ```

### Project Structure

- `contracts/`: Contains the Solidity smart contracts.
  - `OTC_Swap.sol`: Smart contract for the OTC swap.
  - `Decentralized_Marketplace.sol`: Smart contract for the decentralized marketplace.
- `test/`: Contains the test scripts for the smart contracts.
  - `OTCswap.js`: Test cases for the OTC swap contract.
  - `DecentralizedMarketplace.js`: Test cases for the decentralized marketplace contract.
- `hardhat.config.js`: Hardhat configuration file.

### Additional Notes

- Ensure that the Hardhat configuration file (`hardhat.config.js`) is properly set up with the necessary network configurations and Solidity compiler version.
- The test files use the Mocha testing framework and Chai assertion library, which are included in the project dependencies.

## Additional Explanations

Included in the accompanying `.pdf` document are explanations of design decisions, security considerations, and potential edge cases for both completed exercises.

## Conclusion

This submission includes the solutions for Exercise A and Exercise C. For any further questions or clarifications, please do not hesitate to reach out.
