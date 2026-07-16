const { execSync } = require('child_process');
const fs = require('fs');
const https = require('https');

// Helper to run shell commands safely
function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8' }).trim();
  } catch (err) {
    console.error(`Error running command "${cmd}":`, err.message);
    return '';
  }
}

// Get the latest tag or a fallback
function getTags() {
  const tags = run('git tag --sort=-v:refname').split('\n').filter(Boolean);
  return tags;
}

// Main logic
async function main() {
  console.log('Starting AI Release Notes generation...');

  const tags = getTags();
  let baseRef = '';
  let headRef = 'HEAD';

  if (tags.length === 0) {
    console.log('No tags found in repository. Analyzing all commits up to HEAD.');
    // Find initial commit and take first line in case of multiple root commits
    const rootCommits = run('git rev-list --max-parents=0 HEAD').split('\n').filter(Boolean);
    baseRef = rootCommits[0] || '';
  } else if (tags.length === 1) {
    console.log(`Only one tag found (${tags[0]}). Comparing initial commit to ${tags[0]}.`);
    const rootCommits = run('git rev-list --max-parents=0 HEAD').split('\n').filter(Boolean);
    baseRef = rootCommits[0] || '';
    headRef = tags[0];
  } else {
    // tags[0] is the newest tag, tags[1] is the previous one
    baseRef = tags[1];
    headRef = tags[0];
    console.log(`Comparing changes from ${baseRef} to ${headRef}.`);
  }

  if (!baseRef || !headRef) {
    console.error('Could not determine base or head commit reference.');
    fs.writeFileSync('release_notes.md', 'No base or head commits found.');
    return;
  }

  // Get commits list
  const commitLog = run(`git log ${baseRef}..${headRef} --oneline`);
  if (!commitLog) {
    console.log('No commits found between refs.');
    fs.writeFileSync('release_notes.md', 'No changes detected.');
    return;
  }

  console.log('Commits found:\n', commitLog);

  // Get code diff summary
  const diffSummary = run(`git diff --stat ${baseRef}..${headRef}`);
  console.log('Diff Summary:\n', diffSummary);

  // Collect the diff itself, but truncate if it's too large to prevent token limits
  let diffDetails = run(`git diff ${baseRef}..${headRef}`);
  const maxDiffLength = 50000; // ~50KB limit to be safe
  if (diffDetails.length > maxDiffLength) {
    console.log(`Diff is large (${diffDetails.length} chars). Truncating to fit API limits.`);
    diffDetails = diffDetails.substring(0, maxDiffLength) + '\n\n... [Diff truncated due to size] ...';
  }

  const geminiKey = process.env.GEMINI_API_KEY;

  if (!geminiKey) {
    console.log('⚠️ GEMINI_API_KEY environment variable not found. Using offline template fallback.');
    const fallbackNotes = generateOfflineNotes(commitLog, diffSummary);
    fs.writeFileSync('release_notes.md', fallbackNotes);
    console.log('Release notes written to release_notes.md (Offline mode)');
    return;
  }

  console.log('GEMINI_API_KEY found. Generating release notes using Gemini...');
  try {
    const aiNotes = await callGeminiAPI(geminiKey, commitLog, diffSummary, diffDetails);
    fs.writeFileSync('release_notes.md', aiNotes);
    console.log('Release notes written to release_notes.md (AI mode)');
  } catch (error) {
    console.error('Gemini API call failed. Falling back to offline generation.', error.message);
    const fallbackNotes = generateOfflineNotes(commitLog, diffSummary);
    fs.writeFileSync('release_notes.md', fallbackNotes);
  }
}

// Generate classic, clean notes when offline
function generateOfflineNotes(commits, diffSummary) {
  const commitLines = commits.split('\n').filter(Boolean);
  
  const categorized = {
    Features: [],
    Fixes: [],
    Chore: [],
    Other: []
  };

  commitLines.forEach(line => {
    const message = line.substring(line.indexOf(' ') + 1);
    if (/^(feat|feature)/i.test(message)) {
      categorized.Features.push(message);
    } else if (/^(fix|bugfix)/i.test(message)) {
      categorized.Fixes.push(message);
    } else if (/^(chore|style|refactor|test|ci)/i.test(message)) {
      categorized.Chore.push(message);
    } else {
      categorized.Other.push(message);
    }
  });

  let notes = '# 📦 Release Notes\n\n## 🔍 What\'s Changed\n\n';
  
  if (categorized.Features.length > 0) {
    notes += '### 🚀 New Features\n';
    categorized.Features.forEach(msg => notes += `- ${msg}\n`);
    notes += '\n';
  }
  if (categorized.Fixes.length > 0) {
    notes += '### 🐛 Bug Fixes\n';
    categorized.Fixes.forEach(msg => notes += `- ${msg}\n`);
    notes += '\n';
  }
  if (categorized.Other.length > 0) {
    notes += '### 🔄 General Changes\n';
    categorized.Other.forEach(msg => notes += `- ${msg}\n`);
    notes += '\n';
  }
  if (categorized.Chore.length > 0) {
    notes += '### ⚙️ Housekeeping\n';
    categorized.Chore.forEach(msg => notes += `- ${msg}\n`);
    notes += '\n';
  }

  notes += '## 📊 Code Statistics\n```text\n' + diffSummary + '\n```\n';
  notes += '\n*Generated automatically in offline mode.*';
  return notes;
}

// Call Google Gemini API using native https module
function callGeminiAPI(apiKey, commits, diffSummary, diffDetails) {
  return new Promise((resolve, reject) => {
    const model = 'gemini-2.5-flash'; // stable, fast, latest recommended model
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

    const prompt = `You are a professional release manager and a vibe coder's assistant.
Your task is to write a beautiful, engaging, and stylish GitHub Release Notes document based on the Git commits and code diff details provided below.

Guidelines:
- Analyze the actual code changes in the diff to understand *what* changed and *why*, rather than just repeating commit messages.
- Group the changes into logical, stylish sections using emojis (e.g. 🚀 Features, 🐛 Bug Fixes, ⚙️ Performance & Quality, 🧹 Housekeeping).
- Highlight breaking changes clearly using a blockquote or danger callout.
- Keep the tone cool, developer-friendly, and professional.
- Do NOT output HTML tags. Use clean GitHub Markdown.
- Keep bullet points concise and informative.
- Include a summary of code statistics at the end.

---
COMMITS LIST:
${commits}

---
DIFF STATS:
${diffSummary}

---
DETAILED CODE DIFF:
${diffDetails}
`;

    const requestData = JSON.stringify({
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 2048
      }
    });

    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestData),
        'x-goog-api-key': apiKey // Pass the API key securely in headers instead of URL query parameters!
      }
    };

    const req = https.request(url, options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => { responseBody += chunk; });
      res.on('end', () => {
        if (res.statusCode !== 200) {
          // Avoid printing the API key in headers/options errors
          return reject(new Error(`API Error: Status ${res.statusCode} - ${responseBody.replace(apiKey, '[REDACTED]')}`));
        }
        try {
          const parsed = JSON.parse(responseBody);
          const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text;
          if (!text) {
            return reject(new Error('Empty text content received from Gemini. Maybe filtered or invalid request structure.'));
          }
          resolve(text);
        } catch (e) {
          reject(new Error(`Failed to parse Gemini response: ${e.message}`));
        }
      });
    });

    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error('API request timeout (30 seconds) exceeded.'));
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(requestData);
    req.end();
  });
}

// Run main script
main().catch(err => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
