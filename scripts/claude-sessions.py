#!/usr/bin/env python3
"""
Claude Code session viewer — shows sessions with first-message topics, tokens, and cost.

Flags:
  -p, --project atlas      filter by project path (partial match)
  -s, --since 2026-04-01   show sessions on or after date
  -u, --until 2026-04-30   show sessions on or before date
  -l, --limit 20           max sessions to show (default: 30)
  -c, --compact            narrower topic column
  -j, --json               machine-readable output
"""

import json
import glob
import os
import argparse
from datetime import datetime
from urllib.request import urlopen
from urllib.error import URLError

LITELLM_PRICING_URL = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json'

FALLBACK_PRICING: dict[str, tuple] = {
    'claude-opus-4-7':   (15.0, 1.5,  75.0),
    'claude-opus-4-5':   (15.0, 1.5,  75.0),
    'claude-sonnet-4-6':  (3.0, 0.3,  15.0),
    'claude-sonnet-4-5':  (3.0, 0.3,  15.0),
    'claude-haiku-4-5':   (0.8, 0.08,  4.0),
}

_litellm_cache: dict | None = None


def fetch_litellm_pricing() -> dict:
    global _litellm_cache
    if _litellm_cache is not None:
        return _litellm_cache
    try:
        with urlopen(LITELLM_PRICING_URL, timeout=5) as resp:
            _litellm_cache = json.loads(resp.read())
    except (URLError, Exception):
        _litellm_cache = {}
    return _litellm_cache


def get_pricing(model: str) -> tuple:
    """Return (input_per_mtok, cache_read_per_mtok, output_per_mtok)."""
    pricing = fetch_litellm_pricing()
    entry = pricing.get(model)
    if entry and 'input_cost_per_token' in entry:
        return (
            entry['input_cost_per_token'] * 1_000_000,
            entry.get('cache_read_input_token_cost', entry['input_cost_per_token'] * 0.1) * 1_000_000,
            entry['output_cost_per_token'] * 1_000_000,
        )
    for key, prices in FALLBACK_PRICING.items():
        if key in model:
            return prices
    return (3.0, 0.3, 15.0)


def compute_cost(usage: dict, model: str) -> float:
    input_p, cache_read_p, output_p = get_pricing(model)
    cache_creation_p = get_pricing(model)[0]  # same as input
    pricing = fetch_litellm_pricing().get(model, {})
    if 'cache_creation_input_token_cost' in pricing:
        cache_creation_p = pricing['cache_creation_input_token_cost'] * 1_000_000
    return (
        usage.get('input_tokens', 0) * input_p / 1_000_000
        + usage.get('cache_creation_input_tokens', 0) * cache_creation_p / 1_000_000
        + usage.get('cache_read_input_tokens', 0) * cache_read_p / 1_000_000
        + usage.get('output_tokens', 0) * output_p / 1_000_000
    )


def extract_text(content) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get('type') == 'text':
                text = c.get('text', '').strip()
                if text:
                    return text
    return ''


def is_system_message(text: str) -> bool:
    return text.startswith('<') or not text


def _fmt_local(ts: str) -> str:
    dt = datetime.fromisoformat(ts.replace('Z', '+00:00')).astimezone()
    return dt.strftime('%H:%M') + '  ' + dt.strftime('%Y-%m-%d')


def short_project(cwd: str) -> str:
    parts = [p for p in cwd.split('/') if p]
    return '/'.join(parts[-3:]) if len(parts) >= 3 else '/'.join(parts)


def read_session(filepath: str) -> dict | None:
    session_id = os.path.basename(filepath).replace('.jsonl', '')
    first_msg = None
    cwd = None
    last_ts = None
    total_tokens = 0
    total_cost = 0.0

    try:
        with open(filepath, errors='replace') as f:
            for line in f:
                try:
                    d = json.loads(line.strip())
                except json.JSONDecodeError:
                    continue

                if d.get('cwd') and cwd is None:
                    cwd = d['cwd']

                if d.get('timestamp'):
                    last_ts = d['timestamp']

                if (
                    first_msg is None
                    and d.get('type') == 'user'
                    and d.get('message', {}).get('role') == 'user'
                    and not d.get('toolUseResult')
                ):
                    text = extract_text(d['message'].get('content', ''))
                    if not is_system_message(text):
                        first_msg = ' '.join(text.split())

                if d.get('type') == 'assistant':
                    usage = d.get('message', {}).get('usage', {})
                    model = d.get('message', {}).get('model', '')
                    if usage:
                        total_tokens += (
                            usage.get('input_tokens', 0)
                            + usage.get('cache_creation_input_tokens', 0)
                            + usage.get('cache_read_input_tokens', 0)
                            + usage.get('output_tokens', 0)
                        )
                        total_cost += compute_cost(usage, model)
    except OSError:
        return None

    if not last_ts:
        return None

    return {
        'sessionId': session_id,
        'project': short_project(cwd) if cwd else '—',
        'topic': first_msg or '(no message)',
        'totalTokens': total_tokens,
        'totalCost': total_cost,
        'lastActivity': _fmt_local(last_ts),
        'lastActivityTs': last_ts,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Claude Code session viewer with topics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Examples:\n  claude-sessions\n  claude-sessions -p atlas\n  claude-sessions -s 2026-04-01\n  claude-sessions -j',
    )
    parser.add_argument('-p', '--project', help='Filter by project path (partial match)')
    parser.add_argument('-s', '--since', help='Show sessions on or after date (YYYY-MM-DD)')
    parser.add_argument('-u', '--until', help='Show sessions on or before date (YYYY-MM-DD)')
    parser.add_argument('-j', '--json', action='store_true', dest='as_json', help='Output as JSON')
    parser.add_argument('-c', '--compact', action='store_true', help='Narrow topic column')
    parser.add_argument('-l', '--limit', type=int, default=30, help='Max sessions to show (default: 30)')
    args = parser.parse_args()

    # Fetch pricing once up front so all sessions share the same cached data
    fetch_litellm_pricing()

    base = os.path.expanduser('~/.claude/projects/')
    files = glob.glob(base + '**/*.jsonl', recursive=True)

    sessions = []
    for f in sorted(files):
        s = read_session(f)
        if s is None:
            continue
        if args.project and args.project.lower() not in s['project'].lower():
            continue
        if args.since and s['lastActivityTs'][:10] < args.since:
            continue
        if args.until and s['lastActivityTs'][:10] > args.until:
            continue
        sessions.append(s)

    sessions.sort(key=lambda s: s['lastActivityTs'], reverse=True)
    sessions = sessions[: args.limit]

    if args.as_json:
        print(json.dumps(sessions, indent=2))
        return

    if not sessions:
        print('No sessions found.')
        return

    topic_w = 40 if args.compact else 55
    fmt = f"{{:<10}}  {{:<25}}  {{:<{topic_w}}}  {{:>10}}  {{:>8}}  {{}}"

    header = fmt.format('Session', 'Project', 'Topic', 'Tokens', 'Cost', 'Last Activity')
    print(header)
    print('─' * len(header))

    for s in sessions:
        topic = s['topic']
        if len(topic) > topic_w:
            topic = topic[:topic_w - 1] + '…'
        print(fmt.format(
            s['sessionId'][:8],
            s['project'][:25],
            topic,
            f"{s['totalTokens']:,}",
            f"${s['totalCost']:.2f}",
            s['lastActivity'],
        ))


if __name__ == '__main__':
    main()
