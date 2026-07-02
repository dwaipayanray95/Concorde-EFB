import subprocess
import json
import os
from datetime import datetime

def run_git_log():
    # Format: YYYY-MM-DD|abbreviated_hash commit_message
    try:
        result = subprocess.run(
            ["git", "log", '--pretty=format:%ad|%h %s', "--date=short"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split("\n")
    except Exception as e:
        print(f"Error running git log: {e}")
        return []

def main():
    entries_path = "public/changelog/entries.json"
    if not os.path.exists(entries_path):
        # Create default empty JSON if file doesn't exist
        os.makedirs(os.path.dirname(entries_path), exist_ok=True)
        with open(entries_path, "w") as f:
            f.write("[]")

    # Read existing entries
    try:
        with open(entries_path, "r") as f:
            existing_entries = json.load(f)
    except Exception as e:
        print(f"Error reading existing JSON: {e}")
        existing_entries = []

    # Filter out existing "Commits" entries so we can regenerate them dynamically
    # but keep custom release entries (anything whose title is NOT "Commits")
    release_entries = [entry for entry in existing_entries if entry.get("title") != "Commits"]

    # Parse Git Commits
    git_commits = run_git_log()
    commits_by_date = {}

    for line in git_commits:
        if not line or "|" not in line:
            continue
        parts = line.split("|", 1)
        date = parts[0].strip()
        commit_msg = parts[1].strip()

        # Skip boring CI/Merge commit messages
        if "Merge branch" in commit_msg or "Merge pull request" in commit_msg:
            continue

        if date not in commits_by_date:
            commits_by_date[date] = []
        commits_by_date[date].append(commit_msg)

    # Re-blend commits and release logs
    new_entries = []
    
    # 1. Add all hand-written release logs
    new_entries.extend(release_entries)

    # 2. Add "Commits" log blocks for any dates that don't have a release entry on that same day
    release_dates = {entry["date"] for entry in release_entries}
    for date, commits in commits_by_date.items():
        if date not in release_dates:
            new_entries.append({
                "date": date,
                "title": "Commits",
                "items": commits
            })

    # Sort all entries by date descending
    new_entries.sort(key=lambda x: x["date"], reverse=True)

    # Save back to entries.json
    try:
        with open(entries_path, "w") as f:
            json.dump(new_entries, f, indent=4)
        print("Changelog successfully regenerated from git history!")
    except Exception as e:
        print(f"Failed to write entries.json: {e}")

if __name__ == "__main__":
    main()
