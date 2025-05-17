// Deployment script for EscrowService contract on Core Testnet 2
const hre = require("hardhat");

async function main() {
  console.log("Deploying EscrowService contract to Core Testnet 2...");

  // Get the contract factory
  const EscrowService = await hre.ethers.getContractFactory("EscrowService");
  
  // Deploy the contract
  const escrowService = await EscrowService.deploy();

  // Wait for deployment to complete
  await escrowService.waitForDeployment();
  
  const address = await escrowService.getAddress();
  console.log(`EscrowService deployed to: ${address}`);
  console.log("Deployment completed successfully!");
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error during deployment:", error);
    process.exit(1);
  });
