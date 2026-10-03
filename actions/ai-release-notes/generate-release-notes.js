// Writes release notes for BASE_REF..HEAD_REF. Gemini turns the commits and
// the hand-written changelog entries into plain-language notes for end users;
// if there is no key or the API fails, a categorised commit list is written
// instead so a release is never blocked on the AI.
const { execFileSync } = require('child_process');
const fs = require('fs');
const https = require('https');

const env = (k, d = '') => (process.env[k] || d).trim();
const BASE = env('BASE_REF');
const HEAD = env('HEAD_REF', 'HEAD');
const OUT = env('NOTES_OUTPUT', 'release_notes.md');
const PRE = env('IS_PRERELEASE') === 'true';
const VERSION = env('APP_VERSION');
const REPO = env('REPO');

function git(...args) {
  try {
    return execFileSync('git', args, { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }).trim();
  } catch (err) {
    console.error(`git ${args.join(' ')} failed: ${err.message}`);
    return '';
  }
}

function truncate(text, max) {
  return text.length > max ? text.slice(0, max) + '\n... [truncated]' : text;
}

function geminiRequest(apiKey, model, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
          'x-goog-api-key': apiKey,
        },
      },
      (res) => {
        let out = '';
        res.on('data', (c) => (out += c));
        res.on('end', () => {
          if (res.statusCode !== 200) {
            const err = new Error(`Gemini ${res.statusCode}: ${out.split(apiKey).join('[REDACTED]').slice(0, 500)}`);
            err.status = res.statusCode;
            return reject(err);
          }
          try {
            const parts = JSON.parse(out)?.candidates?.[0]?.content?.parts || [];
            const text = parts.filter((p) => !p.thought).map((p) => p.text || '').join('').trim();
            text ? resolve(text) : reject(new Error('Gemini returned no text'));
          } catch (e) {
            reject(new Error(`Bad Gemini response: ${e.message}`));
          }
        });
      },
    );
    req.setTimeout(90000, () => req.destroy(new Error('Gemini request timed out')));
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function callGemini(apiKey, context) {
  const model = env('GEMINI_MODEL', 'gemini-3.6-flash');
  const level = env('GEMINI_THINKING_LEVEL', 'low');
  const prompt = `You write release notes for Concorde EFB, an Electronic Flight Bag app for the DC Designs Concorde in Microsoft Flight Simulator. The readers are flight sim pilots, not developers.

Write GitHub Markdown release notes for ${VERSION ? 'version ' + VERSION : 'this release'}${PRE ? ' (an internal TEST build, not a public release)' : ''}.

Rules:
- Describe what changed for the user, in plain language. No commit hashes, file names, function names or jargon.
- Use only these sections, and omit any that would be empty: "### ✨ New", "### 🛠 Improved", "### 🐛 Fixed".
- One short bullet per change. Merge related commits into one bullet.
- Leave out purely internal work (CI, refactors, tests, docs, dependency bumps). If nothing user-visible changed, write a single line saying this build contains internal improvements only.
- The CHANGELOG ENTRIES below were written by the maintainer and are the most reliable source. Use the commits and code diff only to fill gaps.
- Never invent features. If you are unsure whether something changed, leave it out.
- Start directly with the first section. No title, no intro, no sign-off.${PRE ? '\n- Begin with one line in italics saying this is a test build and may be unstable.' : ''}

=== CHANGELOG ENTRIES ADDED IN THIS RANGE ===
${context.changelog || '(none)'}

=== COMMITS ===
${context.commits}

=== FILES CHANGED ===
${context.stat}

=== CODE DIFF (truncated) ===
${context.diff}
`;
  const body = (withThinking) => ({
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: {
      maxOutputTokens: 4096,
      ...(withThinking ? { thinkingConfig: { thinkingLevel: level } } : {}),
    },
  });
  for (const withThinking of [true, false]) {
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        return await geminiRequest(apiKey, model, body(withThinking));
      } catch (err) {
        console.error(`Gemini attempt failed (thinking=${withThinking}, try ${attempt}): ${err.message}`);
        if (err.status === 400 && withThinking) break; // model rejects thinkingConfig: retry without it
        if (!(err.status === 429 || err.status >= 500 || !err.status)) throw err;
      }
    }
  }
  throw new Error('Gemini failed after retries');
}

function offlineNotes(commitLines) {
  const groups = { '✨ New': [], '🐛 Fixed': [], '🛠 Other changes': [] };
  for (const line of commitLines) {
    if (/^(chore|ci|test|docs|style|refactor)(\(|:)/i.test(line)) continue;
    if (/^feat/i.test(line)) groups['✨ New'].push(line);
    else if (/^fix/i.test(line)) groups['🐛 Fixed'].push(line);
    else groups['🛠 Other changes'].push(line);
  }
  let notes = '';
  for (const [title, items] of Object.entries(groups)) {
    if (items.length) notes += `### ${title}\n${items.map((i) => `- ${i}`).join('\n')}\n\n`;
  }
  return notes || 'This build contains internal improvements only.\n';
}

async function main() {
  const range = BASE ? `${BASE}..${HEAD}` : '';
  const commitArgs = ['log', '--no-merges', '--pretty=format:%s'];
  const commitLines = (range ? git(...commitArgs, range) : git(...commitArgs, '-n', '50', HEAD))
    .split('\n').filter(Boolean);

  if (!commitLines.length) {
    fs.writeFileSync(OUT, 'No changes since the previous build.\n');
    return;
  }

  let notes;
  const apiKey = env('GEMINI_API_KEY');
  if (apiKey) {
    const diffBase = BASE || git('rev-list', '--max-parents=0', HEAD).split('\n')[0];
    const span = `${diffBase}..${HEAD}`;
    const context = {
      commits: truncate(git('log', '--no-merges', '--pretty=format:- %s%n%b', span), 20000),
      stat: truncate(git('diff', '--stat', span), 6000),
      changelog: truncate(
        git('diff', '--unified=0', span, '--', 'public/changelog/entries.json')
          .split('\n').filter((l) => l.startsWith('+') && !l.startsWith('+++')).map((l) => l.slice(1)).join('\n'),
        8000,
      ),
      diff: truncate(git('diff', '--unified=1', span, '--', 'lib', 'tools/simbridge', 'android/app/src', 'windows/runner'), 60000),
    };
    try {
      notes = await callGemini(apiKey, context);
      console.log('Release notes generated with Gemini.');
    } catch (err) {
      console.error(`Falling back to offline notes: ${err.message}`);
    }
  } else {
    console.log('No GEMINI_API_KEY; using offline notes.');
  }
  if (!notes) notes = offlineNotes(commitLines);

  if (REPO && BASE && process.env.RELEASE_TAG) {
    notes += `\n---\n[Full changelog](https://github.com/${REPO}/compare/${BASE}...${process.env.RELEASE_TAG})\n`;
  }
  fs.writeFileSync(OUT, notes.trim() + '\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
