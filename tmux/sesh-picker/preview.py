#!/usr/bin/env python3
"""Render the *most recent* part of a session transcript for the fzf preview.

Usage: preview.py <tool> <path>

Only the tail of the file is read (session .jsonl files are append-only), so
this stays fast even on multi-MB sessions and always shows the freshest turns.
"""
import json
import os
import re
import sys

TAIL_BYTES = 768 * 1024   # only parse the last chunk of the file
MAX_TURNS = 30            # show at most this many recent user/assistant turns
TURN_CHARS = 4000         # truncate any single turn

# ANSI colors (24-bit) tuned to the COSMIC Dark theme. We emit these directly
# and let fzf's --ansi render them, so user vs. assistant are visually distinct.
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
USER_C = "\033[38;2;73;186;200m"    # cyan  #49BAC8  — your prompts
ASSIST_C = "\033[38;2;196;196;196m"  # grey  #C4C4C4  — agent replies
BANNER_C = "\033[38;2;166;218;149m"  # green #A6DA95  — the "newest" banner
RULE_C = "\033[38;2;98;150;190m"     # blue  #6296BE  — separators
CODE_C = "\033[38;2;209;154;102m"    # amber #D19A66  — code spans/blocks
NOBOLD = "\033[22m"                  # turn bold off, keep the current color


ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def visible_width(s):
    """Approx printed width: strip ANSI; count emoji/wide glyphs as 2 cells."""
    s = ANSI_RE.sub("", s)
    w = 0
    for ch in s:
        w += 2 if ord(ch) >= 0x1100 and _is_wide(ch) else 1
    return w


def _is_wide(ch):
    o = ord(ch)
    return (
        0x1100 <= o <= 0x115F      # Hangul Jamo
        or 0x2E80 <= o <= 0xA4CF   # CJK
        or 0xAC00 <= o <= 0xD7A3   # Hangul syllables
        or 0xF900 <= o <= 0xFAFF   # CJK compat
        or 0xFE30 <= o <= 0xFE4F
        or 0xFF00 <= o <= 0xFF60   # fullwidth
        or 0x1F000 <= o <= 0x1FAFF  # emoji/symbols
        or 0x2600 <= o <= 0x27BF   # misc symbols/dingbats
    )


def fit_to_pane(lines):
    """Keep only the last lines that fit the fzf preview pane, so the newest
    content sits at the bottom. fzf sets these env vars for preview commands.
    """
    try:
        rows = int(os.environ.get("FZF_PREVIEW_LINES", "0"))
        cols = int(os.environ.get("FZF_PREVIEW_COLUMNS", "0"))
    except ValueError:
        rows = cols = 0
    if rows <= 0:
        return lines            # not running under fzf — emit everything
    cols = cols if cols > 0 else 80
    kept, used = [], 0
    for ln in reversed(lines):
        wrapped = max(1, -(-visible_width(ln) // cols))  # ceil division
        if used + wrapped > rows and kept:
            break
        kept.append(ln)
        used += wrapped
    kept.reverse()
    return kept


def markdownish(text, base):
    """Light markdown -> ANSI, layered on the turn's base color.

    Handles fenced code blocks, ATX headings, bullets, **bold**, and `code`.
    Not a full renderer — just enough to make transcripts read nicely.
    """
    out = []
    in_fence = False
    for ln in text.split("\n"):
        if ln.lstrip().startswith("```"):
            in_fence = not in_fence
            continue  # hide the ``` fence lines
        if in_fence:
            out.append(f"{CODE_C}{ln}{base}")
            continue
        head = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if head:
            out.append(f"{BOLD}{head.group(2)}{NOBOLD}")
            continue
        ln = re.sub(r"^(\s*)[-*]\s+", r"\1• ", ln)          # bullets
        ln = re.sub(r"\*\*(.+?)\*\*", rf"{BOLD}\1{NOBOLD}", ln)  # **bold**
        ln = re.sub(r"__(.+?)__", rf"{BOLD}\1{NOBOLD}", ln)      # __bold__
        ln = re.sub(r"`([^`]+)`", rf"{CODE_C}\1{base}", ln)     # `inline code`
        out.append(ln)
    return "\n".join(out)


def tail_lines(path):
    """Return decoded lines from the last TAIL_BYTES of the file.

    Drops the first (possibly partial) line when the file is larger than the
    window so we never feed json.loads a truncated line.
    """
    size = os.path.getsize(path)
    with open(path, "rb") as fh:
        if size > TAIL_BYTES:
            fh.seek(size - TAIL_BYTES)
            partial = True
        else:
            partial = False
        data = fh.read()
    text = data.decode("utf-8", errors="ignore")
    lines = text.splitlines()
    if partial and lines:
        lines = lines[1:]
    return lines


def is_tool_noise(text):
    """True if the message is only tool-call/tool-result markers, no real prose."""
    stripped = [ln for ln in text.splitlines() if ln.strip()]
    return bool(stripped) and all(ln.strip().startswith("[tool") for ln in stripped)


def collect_claude(lines):
    turns = []
    for line in lines:
        try:
            d = json.loads(line)
        except Exception:
            continue
        t = d.get("type")
        if t not in ("user", "assistant"):
            continue
        c = d.get("message", {}).get("content")
        if isinstance(c, list):
            parts = []
            for x in c:
                if not isinstance(x, dict):
                    continue
                if x.get("type") == "text":
                    parts.append(x.get("text", ""))
                elif x.get("type") == "tool_use":
                    parts.append(f"[tool: {x.get('name','?')}]")
                elif x.get("type") == "tool_result":
                    parts.append("[tool result]")
            c = "\n".join(p for p in parts if p)
        if isinstance(c, str) and c.strip():
            if c.lstrip().startswith(("<command-", "<local-command")):
                continue
            if is_tool_noise(c):
                continue
            turns.append((t, c.strip()))
    return turns


def collect_codex(lines):
    turns = []
    for line in lines:
        try:
            d = json.loads(line)
        except Exception:
            continue
        p = d.get("payload", {})
        if d.get("type") != "response_item":
            continue
        role = p.get("role")
        if role not in ("user", "assistant"):
            continue
        c = p.get("content")
        if isinstance(c, list):
            c = "\n".join(
                x.get("text", "")
                for x in c
                if isinstance(x, dict) and x.get("type") in ("input_text", "output_text")
            )
        if isinstance(c, str) and c.strip():
            if "AGENTS.md instructions" in c or c.lstrip().startswith("<"):
                continue
            turns.append((role, c.strip()))
    return turns


def main():
    if len(sys.argv) < 3:
        print("usage: preview.py <tool> <path>", file=sys.stderr)
        return
    tool, path = sys.argv[1], sys.argv[2]
    try:
        lines = tail_lines(path)
        turns = collect_claude(lines) if tool == "claude" else collect_codex(lines)
    except (FileNotFoundError, BrokenPipeError):
        return

    # Chronological (oldest -> newest), like the real chat CLI.
    recent = turns[-MAX_TURNS:]
    lines = []
    if len(turns) > len(recent):
        lines.append(f"{DIM}{BANNER_C}╺╸ earlier messages above hidden ╺╸{RESET}")
        lines.append("")
    for role, text in recent:
        if len(text) > TURN_CHARS:
            text = text[:TURN_CHARS] + " …[truncated]"
        # Keep single blank lines between paragraphs, drop bigger gaps.
        text = re.sub(r"\n{3,}", "\n\n", text).strip()
        if role == "user":
            label, color = "🙂 You", USER_C
        else:
            label, color = "🤖 Assistant", ASSIST_C
        lines.append(f"{DIM}{RULE_C}{'─' * 40}{RESET}")
        lines.append(f"{BOLD}{color}{label}{RESET}")
        lines.append("")
        for tl in markdownish(text, color).split("\n"):
            lines.append(f"{color}{tl}{RESET}")
        lines.append("")
    lines.append(f"{BOLD}{BANNER_C}╺╸ ▲ most recent — end of chat ╺╸{RESET}")

    # Trim to the last screenful so fzf (which anchors previews to the top)
    # shows the newest turn at the bottom of the pane with no scrolling.
    try:
        sys.stdout.write("\n".join(fit_to_pane(lines)) + "\n")
    except BrokenPipeError:
        pass


if __name__ == "__main__":
    main()
