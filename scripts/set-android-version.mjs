import { readFile, writeFile } from 'node:fs/promises';

// نسخه از version.json خوانده می‌شود تا منبع واحد برای PWA و APK باشد.
const { version: VERSION, versionCode: VERSION_CODE } = JSON.parse(await readFile('version.json', 'utf8'));
const file = 'android/app/build.gradle';

let text = await readFile(file, 'utf8');
const codePattern = /versionCode\s+\d+/;
const namePattern = /versionName\s+"[^"]*"/;

if (!codePattern.test(text) || !namePattern.test(text)) {
  throw new Error(`Could not find versionCode/versionName in ${file}`);
}

text = text.replace(codePattern, `versionCode ${VERSION_CODE}`);
text = text.replace(namePattern, `versionName "${VERSION}"`);
await writeFile(file, text);

console.log(`Android version set to ${VERSION} (versionCode ${VERSION_CODE})`);
