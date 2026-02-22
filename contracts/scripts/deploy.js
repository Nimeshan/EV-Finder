const hre = require("hardhat");

async function main() {
  console.log("Deploying EVFinder contract...");

  const EVFinder = await hre.ethers.getContractFactory("EVFinder");
  const evFinder = await EVFinder.deploy();

  await evFinder.waitForDeployment();

  const address = await evFinder.getAddress();
  console.log("EVFinder deployed to:", address);
  console.log("Network:", hre.network.name);
  
  // Save deployment address
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    address: address,
    timestamp: new Date().toISOString(),
  };
  
  fs.writeFileSync(
    `deployments/${hre.network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("Deployment info saved to deployments/" + hre.network.name + ".json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


