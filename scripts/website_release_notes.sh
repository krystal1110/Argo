#!/usr/bin/env bash

website_release_notes_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

website_release_notes_defaults() {
  local root_dir
  root_dir="${ROOT_DIR:-$(website_release_notes_repo_root)}"

  WEBSITE_RELEASES_FILE="${WEBSITE_RELEASES_FILE:-$root_dir/website/releases/releases.json}"
  WEBSITE_RELEASES_HTML_FILE="${WEBSITE_RELEASES_HTML_FILE:-$root_dir/website/releases/index.html}"
  WEBSITE_HOME_HTML_FILE="${WEBSITE_HOME_HTML_FILE:-$root_dir/website/index.html}"
  WEBSITE_APPCAST_FILE="${WEBSITE_APPCAST_FILE:-${APPCAST_FILE:-$root_dir/appcast.xml}}"
  WEBSITE_GITHUB_REPOSITORY="${WEBSITE_GITHUB_REPOSITORY:-${GITHUB_REPOSITORY:-krystal1110/Argo}}"
  WEBSITE_APP_NAME="${WEBSITE_APP_NAME:-${APP_NAME:-Argo}}"
  WEBSITE_BREW_INSTALL_REF="${WEBSITE_BREW_INSTALL_REF:-krystal1110/argo/argo}"
}

website_release_notes_generate() {
  website_release_notes_defaults

  python3 - "$WEBSITE_RELEASES_FILE" "$WEBSITE_RELEASES_HTML_FILE" "$WEBSITE_GITHUB_REPOSITORY" "$WEBSITE_APP_NAME" "$WEBSITE_BREW_INSTALL_REF" <<'PY'
import html
import json
import sys
from pathlib import Path

data_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
repository = sys.argv[3]
app_name = sys.argv[4]
brew_install_ref = sys.argv[5]

if not data_path.is_file():
    raise SystemExit(f"Missing website release data: {data_path}")

data = json.loads(data_path.read_text(encoding="utf-8"))
releases = data["releases"] if isinstance(data, dict) else data
if not releases:
    raise SystemExit("Website release data must contain at least one release")

def esc(value):
    return html.escape(str(value), quote=True)

def release_title_id(version, latest=False):
    if latest:
        return "latest-release-title"
    return "release-" + str(version).replace(".", "-") + "-title"

def release_urls(version):
    tag = f"v{version}"
    base = f"https://github.com/{repository}/releases"
    return (
        f"{base}/tag/{tag}",
        f"{base}/download/{tag}/{app_name}-{version}.dmg",
    )

latest = releases[0]
latest_tag_url, latest_dmg_url = release_urls(latest["version"])

parts = [
    "<!doctype html>",
    '<html lang="en">',
    "  <head>",
    '    <meta charset="utf-8">',
    '    <meta name="viewport" content="width=device-width, initial-scale=1">',
    "    <title>Release Notes - Argo</title>",
    '    <meta name="description" content="Release notes for Argo, a native macOS terminal workspace for repositories, worktrees, split panes, previews, SSH sessions, and coding agents.">',
    '    <link rel="icon" href="../assets/app-icon-64.png" sizes="64x64">',
    '    <link rel="stylesheet" href="../styles.css">',
    "  </head>",
    "  <body>",
    '    <header class="site-header">',
    '      <nav class="site-nav" aria-label="Primary navigation">',
    '        <a class="brand" href="../" aria-label="Argo home">',
    '          <img src="../assets/app-icon-64.png" srcset="../assets/app-icon-64.png 1x, ../assets/app-icon-128.png 2x" alt="" width="31" height="31" decoding="async">',
    "          <span>Argo</span>",
    "        </a>",
    '        <div class="nav-links">',
    '          <a href="../">Home</a>',
    '          <a href="../#features">Features</a>',
    '          <a href="./" aria-current="page">Releases</a>',
    '          <a href="../#download">Download</a>',
    '          <a href="https://github.com/krystal1110/Argo">GitHub</a>',
    "        </div>",
    "      </nav>",
    "    </header>",
    "",
    '    <main class="releases-page" aria-labelledby="releases-title">',
    '      <header class="releases-header">',
    '        <p class="section-number">Releases</p>',
    '        <h1 id="releases-title">Release Notes</h1>',
    "        <p>Argo keeps the latest four releases here, with short notes focused on user-visible changes.</p>",
    "      </header>",
    "",
    '      <section class="latest-release" aria-labelledby="latest-release-title">',
    '        <span class="release-badge">Latest</span>',
    '        <div class="release-heading">',
    "          <div>",
    f'            <p class="release-date">{esc(latest["date"])}</p>',
    f'            <h2 id="latest-release-title"><a href="{esc(latest_tag_url)}">Argo {esc(latest["version"])}</a></h2>',
    "          </div>",
    f'          <a class="button primary" href="{esc(latest_dmg_url)}">Download</a>',
    "        </div>",
    f'        <p class="release-summary">{esc(latest["summary"])}</p>',
    f"        <p class=\"install-copy\">Install through Homebrew:<br><code>brew install --cask {esc(brew_install_ref)}</code></p>",
    "      </section>",
]

if len(releases) > 1:
    parts.extend([
        "",
        '      <section class="release-history" aria-label="Previous releases">',
    ])
    for release in releases[1:]:
        tag_url, dmg_url = release_urls(release["version"])
        title_id = release_title_id(release["version"])
        parts.extend([
            f'        <article class="release-card" aria-labelledby="{esc(title_id)}">',
            '          <div class="release-heading">',
            "            <div>",
            f'              <p class="release-date">{esc(release["date"])}</p>',
            f'              <h2 id="{esc(title_id)}"><a href="{esc(tag_url)}">Argo {esc(release["version"])}</a></h2>',
            "            </div>",
            f'            <a class="button secondary" href="{esc(dmg_url)}">Download</a>',
            "          </div>",
            f'          <p class="release-summary">{esc(release["summary"])}</p>',
            "        </article>",
        ])
    parts.append("      </section>")

parts.extend([
    "    </main>",
    "  </body>",
    "</html>",
    "",
])

output_path.write_text("\n".join(parts), encoding="utf-8")
PY
}

website_release_notes_update_homepage_downloads() {
  local version="$1"

  website_release_notes_defaults

  python3 - "$WEBSITE_HOME_HTML_FILE" "$WEBSITE_GITHUB_REPOSITORY" "$WEBSITE_APP_NAME" "$version" <<'PY'
import re
import sys
from pathlib import Path

html_path = Path(sys.argv[1])
repository = re.escape(sys.argv[2])
app_name = re.escape(sys.argv[3])
version = sys.argv[4]

if not html_path.is_file():
    raise SystemExit(f"Missing website homepage: {html_path}")

text = html_path.read_text(encoding="utf-8")
pattern = rf"https://github\.com/{repository}/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/{app_name}-[0-9]+\.[0-9]+\.[0-9]+\.dmg"
replacement = f"https://github.com/{sys.argv[2]}/releases/download/v{version}/{sys.argv[3]}-{version}.dmg"
updated, count = re.subn(pattern, replacement, text)
if count == 0:
    raise SystemExit(f"No homepage release download links found in {html_path}")

html_path.write_text(updated, encoding="utf-8")
PY
}

website_release_notes_update() {
  local version="$1"
  local tag="$2"
  local previous_tag="$3"
  local dmg_path="$4"
  local release_notes_file="$5"

  website_release_notes_defaults

  python3 - "$WEBSITE_RELEASES_FILE" "$WEBSITE_APPCAST_FILE" "$version" "$tag" "$previous_tag" "$dmg_path" "$release_notes_file" <<'PY'
import json
import re
import sys
from datetime import datetime
from email.utils import parsedate_to_datetime
from pathlib import Path

data_path = Path(sys.argv[1])
appcast_path = Path(sys.argv[2])
version = sys.argv[3]
release_notes_file = Path(sys.argv[7])

if not data_path.is_file():
    raise SystemExit(f"Missing website release data: {data_path}")

def load_releases(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    releases = data["releases"] if isinstance(data, dict) else data
    if not isinstance(releases, list):
        raise SystemExit("Website release data must be a list or contain a releases list")
    return releases

def clean_markdown_text(text):
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"^\s*[-*]\s+", "", text)
    return re.sub(r"\s+", " ", text).strip()

def first_two_sentences(text):
    text = clean_markdown_text(text)
    if not text:
        return "Initial public release."
    sentences = re.findall(r"[^.!?]+[.!?]+|[^.!?]+$", text)
    summary = " ".join(part.strip() for part in sentences[:2]).strip()
    if summary and summary[-1] not in ".!?":
        summary += "."
    return summary

def extract_summary(path):
    if not path.is_file():
        return "Initial public release."

    lines = path.read_text(encoding="utf-8").splitlines()
    captured = []
    in_summary = False
    for line in lines:
        stripped = line.strip()
        if stripped == "### Summary":
            in_summary = True
            continue
        if in_summary and stripped.startswith("### "):
            break
        if in_summary and stripped:
            captured.append(stripped)

    if captured:
        return first_two_sentences(" ".join(captured))

    paragraph = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if paragraph:
                break
            continue
        if stripped.startswith("#"):
            continue
        if stripped == "### Install":
            break
        paragraph.append(stripped)

    return first_two_sentences(" ".join(paragraph))

def date_for_version(path, release_version):
    if path.is_file():
        appcast = path.read_text(encoding="utf-8")
        for item_match in re.finditer(r"<item\b[^>]*>(.*?)</item>", appcast, re.DOTALL):
            item = item_match.group(1)
            versions = {
                match.group(1).strip()
                for match in re.finditer(
                    r"<(?:[^:<>]+:)?(?:title|shortVersionString)\b[^>]*>\s*([^<]+?)\s*</(?:[^:<>]+:)?(?:title|shortVersionString)>",
                    item,
                    re.DOTALL,
                )
            }
            if release_version in versions:
                pub_date_match = re.search(r"<pubDate\b[^>]*>\s*([^<]+?)\s*</pubDate>", item, re.DOTALL)
                if pub_date_match:
                    parsed = parsedate_to_datetime(pub_date_match.group(1).strip())
                    return f"{parsed.strftime('%B')} {parsed.day}, {parsed.year}"

    now = datetime.now()
    return f"{now.strftime('%B')} {now.day}, {now.year}"

existing = load_releases(data_path)
new_release = {
    "version": version,
    "date": date_for_version(appcast_path, version),
    "summary": extract_summary(release_notes_file),
}

updated = [new_release]
for release in existing:
    if str(release.get("version")) != version:
        updated.append(release)

data_path.write_text(
    json.dumps({"releases": updated[:4]}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY

  website_release_notes_generate
  website_release_notes_update_homepage_downloads "$version"
}
