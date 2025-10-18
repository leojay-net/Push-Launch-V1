const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Deploy 5 mintable ERC20 tokens for DEX testing.
 * Optionally, seed initial liquidity against WETH using Router2.
 */
async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Read addresses from previous complete deployment
  const WETH = process.env.WETH_ADDRESS || process.env.WETH || null;
  const ROUTER = process.env.ROUTER || null;

  // name/symbol/decimals — as requested: usdt, usdc, dai, bsc, wpush
  const tokensSpec = [
    { name: "USDT", symbol: "USDT", decimals: 6 },
    { name: "USDC", symbol: "USDC", decimals: 6 },
    { name: "DAI", symbol: "DAI", decimals: 18 },
    { name: "BSC", symbol: "BSC", decimals: 18 },
    { name: "WPUSH", symbol: "WPUSH", decimals: 18 },
  ];

  const tokens = [];
  const Mintable = await hre.ethers.getContractFactory("MintableERC20");

  for (const spec of tokensSpec) {
    const t = await Mintable.deploy();
    await t.waitForDeployment();
    const addr = await t.getAddress();
    // initialize metadata once with provided decimals
    const initTx = await t.initialize(spec.name, spec.symbol, spec.decimals);
    await initTx.wait();
    // mint 1B tokens (in token units) to deployer for testing
    const mintTx = await t.mint(
      deployer.address,
      hre.ethers.parseUnits("1000000000", spec.decimals)
    );
    await mintTx.wait();
    tokens.push({ ...spec, address: addr });
    console.log(`✅ ${spec.symbol}: ${addr} (decimals=${spec.decimals})`);
  }

  // Intentionally skipping liquidity seeding as requested
  console.log("\nℹ️  Liquidity seeding skipped.");

  console.log("\nDeployed test tokens:");
  console.log(tokens);

  // Save to deployments directory
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) fs.mkdirSync(deploymentsDir);
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = path.join(deploymentsDir, `test_tokens_${timestamp}.json`);
  const out = {
    network: "Push Chain Testnet",
    chainId: 42101,
    router: ROUTER,
    weth: WETH,
    deployer: deployer.address,
    tokens,
    timestamp: new Date().toISOString(),
  };
  fs.writeFileSync(filename, JSON.stringify(out, null, 2));
  console.log("Saved token addresses:", filename);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
