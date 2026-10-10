import { readFile } from "node:fs/promises";

const expectedVersion = "1.0.33";
const expectedCode = 34;

const version = JSON.parse(
  await readFile("version.json", "utf8")
);

if (
  version.version !== expectedVersion ||
  version.versionCode !== expectedCode
) {
  throw new Error(
    `version.json mismatch: expected ${expectedVersion}/${expectedCode}`
  );
}

const index = await readFile("index.html", "utf8");

if (!index.includes(`<title>Namello ${expectedVersion}</title>`)) {
  throw new Error(`index.html title is not ${expectedVersion}`);
}

const manifests = [
  "manifest.json",
  "manifest-midnight.json",
  "manifest-emerald.json",
  "manifest-royal.json",
  "manifest-graphite.json",
  "manifest-sunset.json",
  "manifest-ruby.json"
];

for (const file of manifests) {
  const path = `public/${file}`;
  const manifest = JSON.parse(
    await readFile(path, "utf8")
  );

  if (
    manifest.name !== `Namello ${expectedVersion}` ||
    manifest.short_name !== `Namello ${expectedVersion}`
  ) {
    throw new Error(`${path} is not ${expectedVersion}`);
  }
}

const sw = await readFile("public/sw.js", "utf8");

if (!sw.includes(`namello-${expectedVersion}-c${expectedCode}`)) {
  throw new Error(
    `Service-worker cache is not namello-${expectedVersion}-c${expectedCode}`
  );
}

console.log(
  `Namello version verified: ${expectedVersion} (versionCode ${expectedCode})`
);
