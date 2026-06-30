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

def lang_text(value):
    escaped = esc(value)
    return f'<span class="lang" data-lang="zh">{escaped}</span><span class="lang" data-lang="en">{escaped}</span>'

def release_row(release):
    tag_url, dmg_url = release_urls(release["version"])
    title_id = release_title_id(release["version"])
    return [
        f'          <article class="release-row" aria-labelledby="{esc(title_id)}">',
        "            <div>",
        f'              <p class="release-date">{lang_text(release["date"])}</p>',
        f'              <h3 id="{esc(title_id)}"><a href="{esc(tag_url)}">Argo {esc(release["version"])}</a></h3>',
        "            </div>",
        f'            <p>{lang_text(release["summary"])}</p>',
        f'            <a class="pill-link" href="{esc(dmg_url)}">Download</a>',
        "          </article>",
    ]

latest = releases[0]
latest_tag_url, latest_dmg_url = release_urls(latest["version"])

parts = [
    "      <!-- RELEASE_NOTES_GENERATED_START -->",
    '      <section class="hero" aria-labelledby="release-title">',
    "        <div>",
    '          <h1 id="release-title"><span class="lang" data-lang="zh">版本记录</span><span class="lang" data-lang="en">Release Notes</span></h1>',
    '          <p class="lead"><span class="lang" data-lang="zh">查看 Argo 最近版本的日期、摘要、下载链接和 GitHub tag。</span><span class="lang" data-lang="en">Review recent Argo versions with dates, short user-facing notes, download links, and GitHub tags.</span></p>',
    '          <div class="cta-row">',
    f'            <a class="button primary" href="{esc(latest_dmg_url)}">Download Argo</a>',
    '            <a class="button secondary" href="../#top"><span class="lang" data-lang="zh">返回首页</span><span class="lang" data-lang="en">Back to home</span></a>',
    '            <a class="button ghost" href="https://github.com/krystal1110/Argo/releases"><span class="lang" data-lang="zh">全部版本</span><span class="lang" data-lang="en">All releases</span></a>',
    "          </div>",
    "        </div>",
    "",
    '        <article class="latest-card" aria-labelledby="latest-release-title">',
    '          <span class="badge">Latest</span>',
    f'          <p class="release-date">{lang_text(latest["date"])}</p>',
    f'          <h2 id="latest-release-title"><a href="{esc(latest_tag_url)}">Argo {esc(latest["version"])}</a></h2>',
    f'          <p>{lang_text(latest["summary"])}</p>',
    '          <div class="command-box">',
    "            <strong>Homebrew</strong>",
    f"            <code>brew install --cask {esc(brew_install_ref)}</code>",
    "          </div>",
    "        </article>",
    "      </section>",
    "",
    '      <section id="history" class="section" aria-labelledby="history-title">',
    '        <div class="section-head">',
    '          <h2 id="history-title"><span class="lang" data-lang="zh">版本、日期、摘要和下载。</span><span class="lang" data-lang="en">Versions, dates, summaries, and downloads.</span></h2>',
    "        </div>",
    '        <div class="release-board" aria-label="Release history">',
]

for release in releases:
    parts.extend(release_row(release))

parts.extend([
    "        </div>",
    "      </section>",
    "",
    '      <section id="resources" class="section" aria-labelledby="resources-title">',
    '        <div class="section-head">',
    '          <h2 id="resources-title"><span class="lang" data-lang="zh">下载、源码和全部版本。</span><span class="lang" data-lang="en">Downloads, source, and full history.</span></h2>',
    "        </div>",
    '        <div class="resources">',
    '          <article class="resource-card">',
    "            <div>",
    '              <span class="badge">DMG</span>',
    "              <h3>Download Argo</h3>",
    '              <p><span class="lang" data-lang="zh">下载最新 macOS 安装包。</span><span class="lang" data-lang="en">Download the latest macOS installer.</span></p>',
    "            </div>",
    f'            <a class="button secondary" href="{esc(latest_dmg_url)}"><span class="lang" data-lang="zh">下载 DMG</span><span class="lang" data-lang="en">Download DMG</span></a>',
    "          </article>",
    '          <article class="resource-card">',
    "            <div>",
    '              <span class="badge">GitHub</span>',
    '              <h3><span class="lang" data-lang="zh">源码与 tag</span><span class="lang" data-lang="en">Source and tags</span></h3>',
    '              <p><span class="lang" data-lang="zh">查看源码、tag 和项目活动。</span><span class="lang" data-lang="en">Browse source code, tags, and project activity.</span></p>',
    "            </div>",
    '            <a class="button ghost" href="https://github.com/krystal1110/Argo"><span class="lang" data-lang="zh">打开 GitHub</span><span class="lang" data-lang="en">Open GitHub</span></a>',
    "          </article>",
    '          <article class="resource-card">',
    "            <div>",
    '              <span class="badge">Archive</span>',
    '              <h3><span class="lang" data-lang="zh">全部版本</span><span class="lang" data-lang="en">All releases</span></h3>',
    '              <p><span class="lang" data-lang="zh">进入完整版本记录页面。</span><span class="lang" data-lang="en">Open the complete release history page.</span></p>',
    "            </div>",
    '            <a class="button ghost" href="https://github.com/krystal1110/Argo/releases"><span class="lang" data-lang="zh">打开全部版本</span><span class="lang" data-lang="en">Open all releases</span></a>',
    "          </article>",
    "        </div>",
    "      </section>",
    "      <!-- RELEASE_NOTES_GENERATED_END -->",
])

start_marker = "      <!-- RELEASE_NOTES_GENERATED_START -->"
end_marker = "      <!-- RELEASE_NOTES_GENERATED_END -->"
if not output_path.is_file():
    raise SystemExit(f"Missing website release page template: {output_path}")
template = output_path.read_text(encoding="utf-8")
start = template.find(start_marker)
end = template.find(end_marker)
if start == -1 or end == -1 or end < start:
    raise SystemExit(f"Missing release notes generated markers in {output_path}")

updated = template[:start] + "\n".join(parts) + template[end + len(end_marker):]
output_path.write_text(updated, encoding="utf-8")
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

updated = re.sub(r"Latest [0-9]+\.[0-9]+\.[0-9]+", f"Latest {version}", updated)
updated = re.sub(r"Get the Argo [0-9]+\.[0-9]+\.[0-9]+ macOS installer", f"Get the Argo {version} macOS installer", updated)
updated = re.sub(r"下载 Argo [0-9]+\.[0-9]+\.[0-9]+ 的 macOS 安装包", f"下载 Argo {version} 的 macOS 安装包", updated)

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
