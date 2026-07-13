import fs from "fs";
import path from "path";
import crypto from "crypto";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const config = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json"), "utf8"));

const entries = [];
const warnings = [];

function hashFileContent(relativePath) {
  const absolutePath = path.join(root, relativePath.replace(/\//g, path.sep));
  if (!fs.existsSync(absolutePath)) {
    return "0";
  }
  const content = fs.readFileSync(absolutePath);
  return crypto.createHash("sha256").update(content).digest("hex").slice(0, 12);
}

function addEntry(instancePath, className, file) {
  const entry = { path: instancePath, className };
  if (file) {
    const normalized = file.replace(/\\/g, "/");
    entry.file = normalized;
    entry.version = hashFileContent(normalized);
  }
  entries.push(entry);
}

function shouldSkipFile(fileName) {
  return fileName.endsWith(".spec.lua") || fileName.endsWith(".server.lua");
}

function shouldSkipDir(dirName) {
  return dirName.endsWith(".spec");
}

function walkLuaDir(relativeDir, instancePath) {
  const absoluteDir = path.join(root, relativeDir);
  if (!fs.existsSync(absoluteDir)) {
    warnings.push(`Папка не найдена: ${relativeDir}`);
    return;
  }

  const initPath = path.join(absoluteDir, "init.lua");
  const hasInit = fs.existsSync(initPath);

  if (hasInit) {
    const folderName = path.basename(relativeDir);
    const modulePath = instancePath ? `${instancePath}.${folderName}` : folderName;
    addEntry(modulePath, "ModuleScript", path.join(relativeDir, "init.lua"));
    instancePath = modulePath;
  }

  for (const entry of fs.readdirSync(absoluteDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name)) {
        continue;
      }
      const subDirPath = path.join(relativeDir, entry.name);
      const subInitPath = path.join(absoluteDir, entry.name, "init.lua");
      if (fs.existsSync(subInitPath)) {
        walkLuaDir(subDirPath, instancePath);
      } else {
        const folderPath = instancePath ? `${instancePath}.${entry.name}` : entry.name;
        addFolder(folderPath);
        walkLuaDir(subDirPath, folderPath);
      }
      continue;
    }

    if (!entry.name.endsWith(".lua") || entry.name === "init.lua" || shouldSkipFile(entry.name)) {
      continue;
    }

    const scriptName = entry.name.replace(/\.client\.lua$/, "").replace(/\.lua$/, "");
    const scriptPath = instancePath ? `${instancePath}.${scriptName}` : scriptName;
    const className = entry.name.endsWith(".client.lua") ? "LocalScript" : "ModuleScript";
    addEntry(scriptPath, className, path.join(relativeDir, entry.name));
  }
}

function addFolder(instancePath) {
  entries.push({ path: instancePath, className: "Folder" });
}

function addValue(instancePath, className, value) {
  entries.push({ path: instancePath, className, value });
}

// Folders
addFolder("Libraries");
addFolder("Tools");
addFolder("UI");
addFolder("Interfaces");
addFolder("Vendor");

// Interfaces UI templates
addEntry("Interfaces.BuildInterfaces", "ModuleScript", "Interfaces/BuildInterfaces.lua");

// Core modules
walkLuaDir("Core", "");

// Tools
walkLuaDir("Tools", "Tools");

// Loader
walkLuaDir("Loader", "");

// UI
walkLuaDir("UI", "UI");

// Libraries (without Signal — added separately)
const librariesDir = path.join(root, "Libraries");
for (const entry of fs.readdirSync(librariesDir, { withFileTypes: true })) {
  if (entry.name === "Signal" || entry.name === "_vendor") {
    continue;
  }
  if (entry.isDirectory()) {
    walkLuaDir(path.join("Libraries", entry.name), "Libraries");
  } else if (entry.name.endsWith(".lua") && !shouldSkipFile(entry.name)) {
    const scriptName = entry.name.replace(/\.lua$/, "");
    addEntry(`Libraries.${scriptName}`, "ModuleScript", path.join("Libraries", entry.name));
  }
}

function copyLuaTree(fromDir, toDir) {
  fs.mkdirSync(toDir, { recursive: true });
  for (const entry of fs.readdirSync(fromDir, { withFileTypes: true })) {
    const fromPath = path.join(fromDir, entry.name);
    const toPath = path.join(toDir, entry.name);
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name)) {
        continue;
      }
      copyLuaTree(fromPath, toPath);
    } else if (entry.name.endsWith(".lua") && !shouldSkipFile(entry.name)) {
      fs.copyFileSync(fromPath, toPath);
    }
  }
}

// Roact vendor — копируем в Libraries/_vendor для публикации на GitHub (submodule не отдаёт raw)
function walkRoactVendor() {
  const sourceDir = path.join(root, "Vendor", "Roact", "src");
  const publishedDir = path.join(root, "Libraries", "_vendor", "Roact", "src");
  if (!fs.existsSync(sourceDir)) {
    warnings.push("Vendor/Roact не найден. Выполни: git submodule update --init --recursive");
    return;
  }

  copyLuaTree(sourceDir, publishedDir);
  const relativeDir = path.join("Libraries", "_vendor", "Roact", "src");
  const absoluteDir = publishedDir;
  const instancePath = "Vendor.Roact";

  addEntry(instancePath, "ModuleScript", path.join(relativeDir, "init.lua"));

  for (const entry of fs.readdirSync(absoluteDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name)) {
        continue;
      }
      const subDirPath = path.join(relativeDir, entry.name);
      const subInitPath = path.join(absoluteDir, entry.name, "init.lua");
      if (fs.existsSync(subInitPath)) {
        walkLuaDir(subDirPath, instancePath);
      } else {
        const folderPath = `${instancePath}.${entry.name}`;
        addFolder(folderPath);
        walkLuaDir(subDirPath, folderPath);
      }
      continue;
    }

    if (!entry.name.endsWith(".lua") || entry.name === "init.lua" || shouldSkipFile(entry.name)) {
      continue;
    }

    const scriptName = entry.name.replace(/\.lua$/, "");
    addEntry(`${instancePath}.${scriptName}`, "ModuleScript", path.join(relativeDir, entry.name));
  }
}

walkRoactVendor();

// Signal dependency (vendored for GitHub raw URLs)
const signalFile = path.join(
  root,
  "node_modules",
  "@quenty",
  "signal",
  "src",
  "Shared",
  "GoodSignal.lua"
);
const vendoredSignal = path.join(root, "Libraries", "_vendor", "GoodSignal.lua");
if (fs.existsSync(signalFile)) {
  fs.mkdirSync(path.dirname(vendoredSignal), { recursive: true });
  fs.copyFileSync(signalFile, vendoredSignal);
  addEntry("Libraries.Signal", "ModuleScript", "Libraries/_vendor/GoodSignal.lua");
} else {
  warnings.push("Signal не найден. Выполни: npm install");
}

// Root-level API module
addEntry("SyncAPI.SyncModule", "ModuleScript", "SyncAPI.lua");

// Support scripts mapped to tool hierarchy
addEntry("SyncAPI", "BindableFunction");
addEntry("SyncAPI.LocalEndpoint", "LocalScript", "Support/LocalAPIEndpoint.client.lua");
addEntry("Assets", "ModuleScript", "Support/Assets.lua");
addEntry("Loaded.ReplicationListener", "LocalScript", "Support/ReplicationListener.client.lua");

// Values and tool parts
addValue("Version", "StringValue", config.toolVersion);
addValue("Loaded", "BoolValue", false);
addValue("Loaded.DescendantCount", "IntValue", 0);
addValue("AutoUpdate", "BoolValue", false);
entries.push({ path: "Handle", className: "Part", properties: { Size: [1.1, 1.1, 1.1], Transparency: 0, CanCollide: false, Massless: true } });

// Sort: parents before children (by dot count, then path)
entries.sort((a, b) => {
  const depthA = a.path ? a.path.split(".").length : 0;
  const depthB = b.path ? b.path.split(".").length : 0;
  if (depthA !== depthB) {
    return depthA - depthB;
  }
  return a.path.localeCompare(b.path);
});

const manifest = {
  ...config,
  generatedAt: new Date().toISOString(),
  entryCount: entries.length,
  entries,
};

fs.writeFileSync(path.join(__dirname, "manifest.json"), JSON.stringify(manifest, null, 2));

console.log(`manifest.json: ${entries.length} entries`);
for (const warning of warnings) {
  console.warn(`WARN: ${warning}`);
}
