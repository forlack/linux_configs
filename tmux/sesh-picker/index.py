#!/usr/bin/env python3
"""Build a unified, cached index of Claude Code + Codex sessions.

Output cache (TSV, one row per session), newest first:
    sort_key <TAB> date_display <TAB> tool <TAB> title <TAB> cwd <TAB> uuid <TAB> path

The cache is keyed by file path + mtime, so re-runs only re-parse files that
changed. First run over all sessions is the only slow one.
"""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
CLAUDE_DIR = HOME / ".claude" / "projects"
CODEX_DIR = HOME / ".codex" / "sessions"
CACHE = HOME / ".cache" / "sesh-picker" / "index.tsv"

# Cap lines scanned per file when extracting metadata (keeps first run fast).
MAX_META_LINES = 400
TITLE_MAX = 80

SKIP_SUBSTR = ("AGENTS.md instructions", "Caveat: The messages below")


def clean_title(text: str) -> str:
    text = " ".join(text.split())
    if len(text) > TITLE_MAX:
        text = text[: TITLE_MAX - 1] + "…"
    return text


def looks_like_real_prompt(text: str) -> bool:
    t = text.strip()
    if not t:
        return False
    # Skip harness-injected blocks: <command-*>, <environment_context>,
    # <local-command…>, <user-…>, AGENTS.md preambles, etc.
    if t.startswith(("<", "#")):
        return False
    if any(s in t for s in SKIP_SUBSTR):
        return False
    return True


def iso_to_epoch(ts: str) -> float:
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def parse_claude(path: Path):
    """Return (epoch, cwd, uuid, title) for a Claude .jsonl session."""
    uuid = path.stem
    ai_title = None
    first_prompt = None
    cwd = str(HOME)
    ts = None
    with path.open(errors="ignore") as fh:
        for i, line in enumerate(fh):
            if i > MAX_META_LINES:
                break
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            if t == "ai-title" and d.get("aiTitle"):
                ai_title = d["aiTitle"]
            elif t == "user":
                if ts is None:
                    ts = d.get("timestamp")
                if d.get("cwd"):
                    cwd = d["cwd"]
                if first_prompt is None:
                    c = d.get("message", {}).get("content")
                    if isinstance(c, list):
                        c = " ".join(
                            x.get("text", "")
                            for x in c
                            if isinstance(x, dict) and x.get("type") == "text"
                        )
                    if isinstance(c, str) and looks_like_real_prompt(c):
                        first_prompt = c
            if ai_title and first_prompt and ts:
                break
    epoch = iso_to_epoch(ts) if ts else path.stat().st_mtime
    title = ai_title or first_prompt or "(untitled)"
    return epoch, cwd, uuid, clean_title(title)


def parse_codex(path: Path):
    """Return (epoch, cwd, uuid, title) for a Codex rollout .jsonl session."""
    uuid = ""
    cwd = str(HOME)
    ts = None
    title = None
    with path.open(errors="ignore") as fh:
        for i, line in enumerate(fh):
            if i > MAX_META_LINES:
                break
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            p = d.get("payload", {})
            if t == "session_meta":
                uuid = p.get("id", uuid)
                cwd = p.get("cwd", cwd)
                ts = p.get("timestamp", ts)
            elif title is None and t == "response_item" and p.get("role") == "user":
                c = p.get("content")
                if isinstance(c, list):
                    c = " ".join(
                        x.get("text", "")
                        for x in c
                        if isinstance(x, dict) and x.get("type") == "input_text"
                    )
                if isinstance(c, str) and looks_like_real_prompt(c):
                    title = c
            if uuid and title and ts:
                break
    if not uuid:
        # UUID is the trailing part of rollout-<ts>-<uuid>.jsonl
        uuid = path.stem.split("-", 2)[-1] if path.stem.count("-") >= 2 else path.stem
    epoch = iso_to_epoch(ts) if ts else path.stat().st_mtime
    return epoch, cwd, uuid, clean_title(title or "(untitled)")


def load_cache():
    """path -> (mtime, full_row_str)."""
    cache = {}
    if not CACHE.exists():
        return cache
    for line in CACHE.read_text(errors="ignore").splitlines():
        parts = line.split("\t")
        if len(parts) != 7:
            continue
        path = parts[6]
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        cache[path] = (mtime, line)
    return cache


def main():
    old = load_cache()
    rows = []
    seen = set()

    def handle(path: Path, tool: str, parser):
        sp = str(path)
        seen.add(sp)
        try:
            mtime = path.stat().st_mtime
        except OSError:
            return
        cached = old.get(sp)
        if cached and abs(cached[0] - mtime) < 1e-6:
            rows.append(cached[1])
            return
        try:
            _start, cwd, uuid, title = parser(path)
        except Exception:
            return
        # Sort/date by file mtime, not session start time: the .jsonl is
        # appended to on every turn, so mtime = last activity = "recently used".
        epoch = mtime
        # Tight display column (shown in the left pane): short date, padded
        # tool tag, then title — single spaces, no tab gaps.
        short = datetime.fromtimestamp(epoch).strftime("%m-%d %H:%M")
        display = f"{short} {tool:<6} {title}"
        rows.append(
            "\t".join([f"{epoch:.0f}", display, tool, title, cwd, uuid, sp])
        )

    if CLAUDE_DIR.is_dir():
        for path in CLAUDE_DIR.glob("*/*.jsonl"):
            handle(path, "claude", parse_claude)
    if CODEX_DIR.is_dir():
        for path in CODEX_DIR.glob("*/*/*/rollout-*.jsonl"):
            handle(path, "codex", parse_codex)

    # newest first by epoch (field 0)
    rows.sort(key=lambda r: int(r.split("\t", 1)[0]), reverse=True)
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text("\n".join(rows) + ("\n" if rows else ""))
    if "--verbose" in sys.argv:
        print(f"indexed {len(rows)} sessions -> {CACHE}", file=sys.stderr)


if __name__ == "__main__":
    main()
