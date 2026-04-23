#!/usr/bin/env python3
"""
Claude Code session viewer — shows sessions with first-message topics, tokens, and cost.

Flags:
  --project atlas      filter by project path (partial match)
  --since 2026-04-01   show sessions on or after date
  --until 2026-04-30   show sessions on or before date
  --limit 20           max sessions to show (default: 50)
  --compact            narrower topic column
  --json               machine-readable output
"""

import json
import glob
import os
import sys
import argparse

MODEL_PRICING = {
    'claude-opus-4-7':  (15.0, 1.5, 75.0),
    'claude-opus-4-5':  (15.0, 1.5, 75.0),
    'claude-sonnet-4-6': (3.0, 0.3, 15.0),
    'claude-sonnet-4-5': (3.0, 0.3, 15.0),
    'claude-haiku-4-5':  (0.8, 0.08, 4.0),
}

def get_pricing(model: str) -> tuple:
    for key, prices in MODEL_PRICING.items():
        if key in model:
            return prices
    return (3.0, 0.3, 15.0)


def compute_cost(usage: dict, model: str) -> float:
    input_p, cache_read_p, output_p = get_pricing(model)
    return (
        usage.get('input_tokens', 0) * input_p / 1_000_000
        + usage.get('cache_creation_input_tokens', 0) * input_p / 1_000_000
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
        'lastActivity': last_ts[:10],
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Claude Code session viewer with topics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Examples:\n  claude-sessions\n  claude-sessions --project atlas\n  claude-sessions --since 2026-04-01\n  claude-sessions --json',
    )
    parser.add_argument('--project', help='Filter by project path (partial match)')
    parser.add_argument('--since', help='Show sessions on or after date (YYYY-MM-DD)')
    parser.add_argument('--until', help='Show sessions on or before date (YYYY-MM-DD)')
    parser.add_argument('--json', action='store_true', dest='as_json', help='Output as JSON')
    parser.add_argument('--compact', action='store_true', help='Narrow topic column')
    parser.add_argument('--limit', type=int, default=50, help='Max sessions to show (default: 50)')
    args = parser.parse_args()

    base = os.path.expanduser('~/.claude/projects/')
    files = glob.glob(base + '**/*.jsonl', recursive=True)

    sessions = []
    for f in sorted(files):
        s = read_session(f)
        if s is None:
            continue
        if args.project and args.project.lower() not in s['project'].lower():
            continue
        if args.since and s['lastActivity'] < args.since:
            continue
        if args.until and s['lastActivity'] > args.until:
            continue
        sessions.append(s)

    sessions.sort(key=lambda s: s['lastActivity'], reverse=True)
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
