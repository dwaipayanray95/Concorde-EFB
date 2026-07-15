const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const DEFAULT_ALLOWED = ['MIT', 'BSD-3-CLAUSE', 'BSD-2-CLAUSE', 'APACHE-2.0', 'ISC', 'UNLICENSE', 'WTFPL', 'CC0-1.0', 'BSD'];
const DEFAULT_BLOCKED = ['GPL-2.0', 'GPL-3.0', 'AGPL-3.0', 'LGPL-2.0', 'LGPL-2.1', 'LGPL-3.0', 'GPL', 'AGPL'];

function fetchJson(url) {
  return new Promise((resolve) => {
    https.get(url, { headers: { 'User-Agent': 'ez-github-scripts-license-guard' } }, (res) => {
      let body = '';
      if (res.statusCode !== 200) {
        return resolve(null);
      }
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

// Scrape license from pub cache or fall back to pub.dev metrics API
async function getFlutterLicense(pkgName, version) {
  // Option 1: Look in local pub-cache
  const home = os.homedir();
  const cacheDirs = [
    path.join(home, '.pub-cache', 'hosted', 'pub.dev', `${pkgName}-${version}`),
    path.join(home, '.pub-cache', 'hosted', 'pub.dartlang.org', `${pkgName}-${version}`),
    path.join(home, 'AppData', 'Local', 'Pub', 'Cache', 'hosted', 'pub.dev', `${pkgName}-${version}`) // Windows
  ];

  for (const cacheDir of cacheDirs) {
    if (fs.existsSync(cacheDir)) {
      const licenseFiles = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING'];
      for (const file of licenseFiles) {
        const fullPath = path.join(cacheDir, file);
        if (fs.existsSync(fullPath)) {
          const content = fs.readFileSync(fullPath, 'utf8').substring(0, 1000).toUpperCase();
          if (content.includes('MIT LICENSE') || content.includes('PERMISSION IS HEREBY GRANTED')) return 'MIT';
          if (content.includes('APACHE LICENSE') || content.includes('APACHE 2.0')) return 'Apache-2.0';
          if (content.includes('BSD')) return 'BSD';
          if (content.includes('GNU GENERAL PUBLIC LICENSE') || content.includes('GPL')) return 'GPL';
        }
      }
    }
  }

  // Option 2: Fall back to pub.dev score metrics API
  const metrics = await fetchJson(`https://pub.dev/api/packages/${pkgName}/metrics`);
  if (metrics && metrics.scorecard && metrics.scorecard.derivedTags) {
    const tags = metrics.scorecard.derivedTags;
    // Look for license tags (e.g. "license:mit", "license:apache-2.0")
    const licenseTag = tags.find(t => t.startsWith('license:'));
    if (licenseTag) {
      return licenseTag.replace('license:', '').toUpperCase();
    }
  }

  return 'Unknown';
}

// Scans pubspec.lock for Dart dependencies
async function scanFlutterDeps() {
  const file = 'pubspec.lock';
  if (!fs.existsSync(file)) return [];

  console.log(`Found ${file}. Scanning Dart/Flutter dependencies...`);
  const content = fs.readFileSync(file, 'utf8');
  
  const packages = [];
  const lines = content.split('\n');
  let currentPackage = null;
  let isHosted = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const pkgMatch = line.match(/^  ([a-zA-Z0-9_-]+):/);
    if (pkgMatch) {
      if (currentPackage && isHosted) {
        packages.push(currentPackage);
      }
      currentPackage = { name: pkgMatch[1], version: '' };
      isHosted = false;
    }
    if (currentPackage) {
      const sourceMatch = line.match(/    source: (\w+)/);
      if (sourceMatch && sourceMatch[1] === 'hosted') {
        isHosted = true;
      }
      const versionMatch = line.match(/    version: "([^"]+)"/);
      if (versionMatch) {
        currentPackage.version = versionMatch[1];
      }
    }
  }
  if (currentPackage && isHosted) {
    packages.push(currentPackage);
  }

  console.log(`Found ${packages.length} hosted packages. Checking licenses...`);
  
  const results = [];
  // Process in concurrent batches of 10
  const batchSize = 10;
  for (let i = 0; i < packages.length; i += batchSize) {
    const batch = packages.slice(i, i + batchSize);
    const promises = batch.map(async (pkg) => {
      const license = await getFlutterLicense(pkg.name, pkg.version);
      return { name: pkg.name, version: pkg.version, license, source: 'pub.dev' };
    });
    const batchResults = await Promise.all(promises);
    results.push(...batchResults);
  }

  return results;
}

// Scans package-lock.json for Node dependencies
function scanNodeDeps() {
  const file = 'package-lock.json';
  if (!fs.existsSync(file)) return [];

  console.log(`Found ${file}. Scanning Node dependencies...`);
  try {
    const raw = fs.readFileSync(file, 'utf8');
    const data = JSON.parse(raw);
    const results = [];

    if (data.packages) {
      for (const [key, val] of Object.entries(data.packages)) {
        if (!key) continue;
        const name = key.replace(/^node_modules\//, '');
        if (!name || name.includes('node_modules')) continue;
        const license = val.license || 'Unknown';
        results.push({ name, version: val.version || '', license, source: 'npm' });
      }
    }
    return results;
  } catch (err) {
    console.error('Failed to parse package-lock.json:', err.message);
    return [];
  }
}

async function main() {
  const allowed = (process.env.ALLOWED_LICENSES || '').split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
  const blocked = (process.env.BLOCKED_LICENSES || '').split(',').map(s => s.trim().toUpperCase()).filter(Boolean);

  const allowedList = allowed.length > 0 ? allowed : DEFAULT_ALLOWED;
  const blockedList = blocked.length > 0 ? blocked : DEFAULT_BLOCKED;

  console.log('Allowed licenses:', allowedList);
  console.log('Blocked licenses:', blockedList);

  const flutterDeps = await scanFlutterDeps();
  const nodeDeps = scanNodeDeps();
  const allDeps = [...flutterDeps, ...nodeDeps];

  if (allDeps.length === 0) {
    console.log('No dependencies found to check.');
    fs.writeFileSync('license_report.md', '### 📜 License Report\nNo dependencies detected.');
    return;
  }

  let violationsCount = 0;
  let report = '### 📜 Dependency License Guard Report\n\n';
  report += '| Package | Version | Ecosystem | License | Status |\n';
  report += '|---|---|---|---|---|\n';

  allDeps.forEach(dep => {
    const lic = dep.license.toUpperCase();
    let status = '✅ Pass';
    
    // Strict compliance checks
    const isBlocked = blockedList.some(b => lic === b || (lic.includes(b) && b !== 'GPL' && b !== 'LGPL') || (b === 'GPL' && lic === 'GPL') || (b === 'LGPL' && lic === 'LGPL'));
    const isAllowed = allowedList.some(a => lic.includes(a));

    if (isBlocked) {
      status = '❌ **Blocked**';
      violationsCount++;
    } else if (!isAllowed && dep.license !== 'Unknown') {
      status = '⚠️ *Warning (Verify)*';
    } else if (dep.license === 'Unknown') {
      status = '❓ Unknown';
    }

    report += `| \`${dep.name}\` | ${dep.version} | ${dep.source} | ${dep.license} | ${status} |\n`;
  });

  fs.writeFileSync('license_report.md', report);
  console.log(`\nLicense check complete. Found ${violationsCount} violations.`);
  console.log(report);

  if (violationsCount > 0 && process.env.FAIL_ON_VIOLATION === 'true') {
    console.error('❌ License compliance verification failed. Blocked licenses were found.');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('License checker failed:', err);
  process.exit(1);
});
