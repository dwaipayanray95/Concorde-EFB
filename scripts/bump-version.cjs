const fs = require('fs');
const path = require('path');

const pubspecPath = path.join(__dirname, '..', 'pubspec.yaml');
const versionDartPath = path.join(__dirname, '..', 'lib', 'core', 'app_version.dart');

// 1. Read pubspec.yaml
let pubspec = fs.readFileSync(pubspecPath, 'utf8');
const versionMatch = pubspec.match(/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)/m);

if (!versionMatch) {
  console.error('Could not find version in pubspec.yaml');
  process.exit(1);
}

const currentFullVersion = versionMatch[1];
const buildNumber = parseInt(versionMatch[2], 10);
const [major, minor, patch] = currentFullVersion.split('.').map(Number);

// 2. Bump minor version as requested (x.y.z -> x.y+1.z)
const nextMinor = minor + 1;
const nextFullVersion = `${major}.${nextMinor}.${patch}`;
const nextPubspecVersion = `${nextFullVersion}+${buildNumber}`;

// 3. Update pubspec.yaml
pubspec = pubspec.replace(/^version: .*/m, `version: ${nextPubspecVersion}`);
fs.writeFileSync(pubspecPath, pubspec);

// 4. Update lib/core/app_version.dart
const displayVersion = `V${major}.${nextMinor}`;
const versionDartContent = `class AppVersion {
  static const String full = '${nextFullVersion}';
  static const String display = '${displayVersion}';
}
`;
fs.writeFileSync(versionDartPath, versionDartContent);

console.log(`Bumped version from ${currentFullVersion} to ${nextFullVersion}`);
console.log(`User-facing version: ${displayVersion}`);
