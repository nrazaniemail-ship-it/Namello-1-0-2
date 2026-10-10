import { readFile } from "node:fs/promises";

const expectedVersion = "1.0.33";
const expectedCode = 34;

const version = JSON.parse(await readFile("version.json", "utf8"));
if (version.version !== expectedVersion || version.versionCode !== expectedCode) {
  throw new Error(`version.json mismatch: expected ${expectedVersion}/${expectedCode}`);
}

const index = await readFile("index.html", "utf8");
if (!index.includes(`<title>Namello ${expectedVersion}</title>`)) {
  throw new Error("index.html title is not 1.0.33");
}

for (const file of [
  "manifest.json",
  "manifest-midnight.json",
  "manifest-emerald.json",
  "manifest-royal.json",
  "manifest-graphite.json",
  "manifest-sunset.json",
  "manifest-ruby.json"
]) {
  const m = JSON.parse(await readFile(file, "utf8"));
  if (m.name !== `Namello ${expectedVersion}` || m.short_name !== `Namello ${expectedVersion}`) {
    throw new Error(`${file} is not ${expectedVersion}`);
  }
}

const sw = await readFile("sw.js", "utf8");
if (!sw.includes("namello-1.0.33-c34")) {
  throw new Error("Service-worker cache is not 1.0.33-c34");
}

console.log(`Namello version verified: ${expectedVersion} (versionCode ${expectedCode})`);
