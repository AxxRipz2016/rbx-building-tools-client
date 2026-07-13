import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "Interfaces", "BuildInterfaces.lua");

let content = fs.readFileSync(sourcePath, "utf8");

const prelude = `-- Автоматически сгенерированный UI-скрипт
-- Собирает все GUI-шаблоны в Tool.Interfaces

local workspace = _G.__bt_interfaces_root or (script and script.Parent)
assert(workspace, "BuildInterfaces: папка Interfaces не найдена")

`;

if (!content.includes("return true")) {
  const body = content.replace(/^--[\s\S]*?(?=do\n--\s*Элемент:)/, "");
  const sections = body.split(/(?=--\s*Элемент:)/g).filter(Boolean);
  const wrapped = sections.map((section) => `do\n${section}end\n`).join("\n");
  content = `${prelude}${wrapped}\nreturn true\n`;
  fs.writeFileSync(sourcePath, content);
  console.log(`BuildInterfaces.lua: ${sections.length} UI-блоков обёрнуто в do/end`);
}
