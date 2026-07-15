const { execSync } = require('child_process');
const fs = require('fs');

function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8' }).trim();
  } catch (err) {
    return '';
  }
}

// Get the date of a tag/ref
function getRefDate(ref) {
  const dateStr = run(`git log -1 --format=%ai ${ref}`);
  if (!dateStr) return '';
  // Format to YYYY-MM-DD
  const match = dateStr.match(/^(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function main() {
  try {
    console.log('Generating/updating CHANGELOG.md...');
    const changelogFile = 'CHANGELOG.md';
    
    // Fetch tags and commits
    const commits = run('git log --oneline').split('\n').filter(Boolean);
    if (commits.length === 0) {
      console.log('No git history found.');
      return;
    }

    const tagsRaw = run('git tag -l --sort=-creatordate').split('\n').filter(Boolean);
    let contents = `# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n`;
    
    // If there is an existing changelog, we preserve everything under the first generated tag
    // to protect manual edits!
    let existingContent = '';
    if (fs.existsSync(changelogFile)) {
      existingContent = fs.readFileSync(changelogFile, 'utf8');
    }

    if (tagsRaw.length === 0) {
      // Single unreleased section
      const dateToday = new Date().toISOString().split('T')[0];
      contents += `## Unreleased (${dateToday})\n\n`;
      contents += formatCommits(commits);
    } else {
      let lastTag = 'HEAD';
      for (const tag of tagsRaw) {
        const tagCommits = run(`git log ${tag}..${lastTag} --oneline`).split('\n').filter(Boolean);
        if (tagCommits.length > 0) {
          const dateStr = getRefDate(lastTag === 'HEAD' ? 'HEAD' : lastTag);
          contents += `## ${lastTag === 'HEAD' ? 'Unreleased' : lastTag}${dateStr ? ` (${dateStr})` : ''}\n\n`;
          contents += formatCommits(tagCommits);
        }
        
        // If we find the first tag already documented in existing changelog,
        // we can copy the historical changelog content and stop parsing older tags!
        if (existingContent && existingContent.includes(`## ${tag}`)) {
          console.log(`Tag ${tag} already documented. Appending historical logs...`);
          const index = existingContent.indexOf(`## ${tag}`);
          contents += existingContent.substring(index);
          fs.writeFileSync(changelogFile, contents);
          console.log('CHANGELOG.md updated successfully preserving history.');
          return;
        }
        
        lastTag = tag;
      }
      
      // Commits before the first tag
      const firstTagCommits = run(`git log ${lastTag} --oneline`).split('\n').filter(Boolean);
      if (firstTagCommits.length > 0) {
        const dateStr = getRefDate(lastTag);
        contents += `## ${lastTag}${dateStr ? ` (${dateStr})` : ''}\n\n`;
        contents += formatCommits(firstTagCommits);
      }
    }

    fs.writeFileSync(changelogFile, contents);
    console.log('CHANGELOG.md updated successfully.');
  } catch (error) {
    console.error('Failed to generate changelog:', error.message);
    process.exit(1);
  }
}

function formatCommits(commitsList) {
  const categories = {
    Features: [],
    Fixes: [],
    Maintenance: []
  };

  commitsList.forEach(line => {
    const msg = line.substring(line.indexOf(' ') + 1);
    if (/^(feat|feature)/i.test(msg)) {
      categories.Features.push(msg);
    } else if (/^(fix|bugfix)/i.test(msg)) {
      categories.Fixes.push(msg);
    } else {
      categories.Maintenance.push(msg);
    }
  });

  let output = '';
  if (categories.Features.length > 0) {
    output += `### Added\n`;
    categories.Features.forEach(c => output += `- ${c}\n`);
    output += `\n`;
  }
  if (categories.Fixes.length > 0) {
    output += `### Fixed\n`;
    categories.Fixes.forEach(c => output += `- ${c}\n`);
    output += `\n`;
  }
  if (categories.Maintenance.length > 0) {
    output += `### Other Changes\n`;
    categories.Maintenance.forEach(c => output += `- ${c}\n`);
    output += `\n`;
  }
  return output;
}

main();
