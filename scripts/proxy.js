#!/usr/bin/env node

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

// Get the command and arguments
const [, , command, ...args] = process.argv;

if (!command) {
  // Show available commands like npm run does
  console.log("Available commands:");
  console.log("");

  try {
    const corePackagePath = path.join(__dirname, "../core/package.json");
    const packageJson = JSON.parse(fs.readFileSync(corePackagePath, "utf8"));

    const scripts = packageJson.scripts || {};
    const maxLength = Math.max(...Object.keys(scripts).map((key) => key.length));

    Object.entries(scripts).forEach(([name, script]) => {
      const padding = " ".repeat(maxLength - name.length + 2);
      console.log(`  ${name}${padding}${script}`);
    });

    console.log("");
    console.log("Usage: npm run core <command>");
    console.log("Example: npm run core build:local");
  } catch (error) {
    console.error("Error reading core package.json:", error.message);
    process.exit(1);
  }

  process.exit(0);
}

// Run the command in the frontend workspace
const child = spawn("npm", ["run", command, ...args], {
  cwd: path.join(__dirname, "../core"),
  stdio: "inherit",
  shell: true,
});

child.on("close", (code) => {
  process.exit(code);
});
