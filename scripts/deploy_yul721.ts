import { ethers } from "hardhat";
import hardhat from "hardhat";
const prompt = require('prompt-sync')();

async function main() {
  const confirm = prompt(`Deploy Yul721 to ${hardhat.network.name}? CONFIRM? `);
  if(confirm != 'CONFIRM') {
    console.log("Abandoning");
    process.exit(0)
  }

  const admin = (await ethers.getSigners())[0];

  const yul = await ethers.deployContract("Yul721", [admin.address]);
  await yul.waitForDeployment()

  console.log(
    `Yul721 deployed to ${yul.target}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
