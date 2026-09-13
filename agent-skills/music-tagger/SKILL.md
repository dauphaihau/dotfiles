---
name: music-tagger
description: Use when a folder of audio files has missing or unusable metadata and filenames must be turned into ID3 tags. Scans the folder, proposes title/artist per file in a reviewable Markdown table, and after the user accepts, applies the tags and embeds lyrics fetched from LRCLIB.
allowed-tools: Read, Write, Glob, Bash(zsh:*), Bash(ffprobe:*), Bash(jq:*), Bash(eyeD3:*), Bash(curl:*), Bash(date:*), Bash(stat:*)
---

# Music Tagger

Turn messy filenames into MP3 tags: scan → analyze → write a proposal → **stop** → apply only on explicit acceptance → verify. Lyrics are fetched and embedded by default; a tags-only run is the opt-out.

Tagging is done by the user's `mtag` zsh function. Do not invent a second tagger; `apply.sh` already sources and calls it.

Skill directory (from the load header, also addressable as `skill://music-tagger`): `zsh <skill-dir>/scripts/{scan,lyrics,apply}.sh`. Those scripts share `scripts/lib.zsh`; never re-implement proposal parsing inline.

## Phase 1 — Scan

```bash
zsh <skill-dir>/scripts/scan.sh "<folder>"
```

Add `--recursive` only if the user wants subfolders included. Scan output is TSV — that is `scan.sh`'s own machine format, not the proposal; only the proposal is Markdown. Columns are `FILE EXT TITLE ARTIST DURATION SIZE`, with `FILE` relative to the `# dir:` line.

If the folder yields zero files, say so and stop.

## Phase 2 — Analyze each row

Work from `FILE` plus whatever `TITLE`/`ARTIST` already exist. The goal is only to fill what is missing or obviously wrong.

Strip noise from the basename:

- bracketed suffixes: `[Official Audio]`, `(Lyrics)`, `(HD)`, `[MV]`, `(Official Video)`, `[4K]`
- quality/bitrate tokens: `320kbps`, `128 kbps`, `HQ`, `HD`, `FLAC`, `MP3`
- separators and filler: `_`, `www.*` domains, ` - Topic`, yt-dlp video IDs (11-char `[A-Za-z0-9_-]` tail)

Then split what remains on the first strong separator: ` - `, ` – `, ` — `, `_-_`, `|`, `~`.
Decide which side is title and which is artist. `Artist - Title` is the yt-dlp convention and the most common shape, but `Title - Artist` does occur; use casing, known artist naming, and the rest of the folder (a repeated leading segment is almost always the artist) as evidence.

Hard rules:

- **Never invent metadata.** No guessed album names, no "the artist is probably X". If the split is not defensible, emit `ASK` with `?` and let the user fill it in.
- Never emit tag fields outside title and artist. The `mtag` function has no album, track, genre, or year support. (`LYRICS` is a file path, not a tag field — see Phase 3.)
- `-` means "leave this field unchanged". Never use `-` as a literal value.
- If a file already has both title and artist, use `SKIP` unless the user explicitly asked to overwrite.

## Phase 3 — Write the proposal

Write `<folder>/mtag-proposal.md` — a Markdown file the user reads and edits: a short header, then one table row per file.

```md
# music-tagger proposal

- dir: /absolute/folder/path
- generated: 2026-09-13T17:20:00
- apply: `zsh <skill-dir>/scripts/apply.sh "<this file>" --yes`

| STATUS | FILE | TITLE | ARTIST | LYRICS | CONF | NOTE |
| --- | --- | --- | --- | --- | --- | --- |
| OK | 01 - Song Name_[Official Audio]_320kbps.mp3 | Song Name | Real Artist | - | high | dropped [Official Audio], 320kbps |
| OK | Real Artist - Track Name (HD).mp3 | Track Name | Real Artist | .mtag-lyrics/real-artist-track-name.txt | high | artist-first split |
| ASK | unknown_1.mp3 | ? | ? | - | low | no separable title or artist |
| SKIP | already-tagged.mp3 | - | - | - | - | has title and artist already |
```

- `OK` — apply these values. Both `TITLE` and `ARTIST` filled, or one filled and the other `-`.
- `ASK` — needs a human decision; never applied.
- `SKIP` — deliberately left alone.
- `UNSUPPORTED` — not an MP3 (see risks).

`LYRICS` holds a **path** to a plain-text lyrics file — relative to the folder, absolute also accepted — or `-` for none. Lyric text is never written into the proposal: a Markdown table row cannot contain newlines, so inlining even one lyric would destroy the table. Write `-` when you create the proposal and leave the cell alone; Phase 5 fills it in.

Format rules:

- Exactly seven cells per row, in the column order above. `apply.sh` rejects a row with the wrong cell count rather than guessing.
- `TITLE`, `ARTIST`, and `NOTE` may contain spaces; do not quote cells and do not pad them for alignment — padding is trimmed either way, so write plain unaligned rows.
- A literal `|` inside any value would split the row. Emit such a row as `ASK` with the reason in `NOTE` instead of an `OK` row.
- Only table rows are read. Title lines, bullets, blank lines, and anything else in the file are ignored, so the header block can be written freely.
- `CONF` is `high|medium|low`. `NOTE` is one short reason: which noise was dropped, how the split was decided, or why it is `ASK`.

Copy `FILE` values verbatim from scan output. Never rename, reorder, or normalize them; only `TITLE`/`ARTIST` are meant to be edited.

`mtag` renames the file to `<title>.mp3` in the same folder, so state the resulting filename for each `OK` row when you report.

## Phase 4 — Stop

Print the proposal path, the per-status counts, and the list of `OK` rows with their resulting filenames. Say that lyrics will be fetched from LRCLIB on acceptance unless the user says no. Then stop and wait. Never run `mtag` or `apply.sh --yes` before the user accepts.

The user accepts by editing the table in place and saying go. Re-read the file after acceptance; do not reuse values you had in memory.

## Phase 5 — Apply

### 5a. Lyrics — always, unless the user opted out

Run this for every accepted proposal. Skip it only when the user asked for tags only (`--no-lyrics`, "no lyrics", "just tags").

```bash
zsh <skill-dir>/scripts/lyrics.sh "<folder>/mtag-proposal.md"   # add --force to refetch staged files
```

It queries LRCLIB per `OK` row (artist + title), keeps candidates within 3s of the file's own duration, prefers a normalized exact title match, writes the plain lyrics to `<folder>/.mtag-lyrics/<artist>-<title>.txt`, and prints one line per row:

```
LYRICS <TAB> FILE <TAB> PATH|- <TAB> STATUS <TAB> DETAIL
```

- `match` — patch that row's `LYRICS` cell with `PATH` (as printed, relative to the folder).
- `cached` — a usable file is already staged; patch the cell with `PATH`.
- `ambiguous` — candidates matched but the title was not exact. Leave `-` and tell the user what was found; never guess a lyric source.
- `none` — leave `-`. This is normal for covers, live takes, and non-mainstream catalogs.
- `error` — network or IO failure for that row; leave `-`, report it, and continue. Do not abort the whole run.

Patch only the `LYRICS` cells — the column is 5th. Do not reorder, rewrap, or re-align other cells, and never paste lyric text into the table.

If any row came back `match`, show the match details (track, artist, duration, diff) and get one confirmation before embedding, so a wrong match is caught before it is written. If every row is `none`/`ambiguous`/`cached`, the table did not change and you can go straight on.

### 5b. Tag

Dry run first, then execute after acceptance:

```bash
zsh <skill-dir>/scripts/apply.sh "<folder>/mtag-proposal.md"        # prints WOULD lines, writes nothing
zsh <skill-dir>/scripts/apply.sh "<folder>/mtag-proposal.md" --yes  # executes
```

`apply.sh` handles the mechanics so they are identical every run:

- sources `~/.aliases/media/tag-audio.sh` and calls `mtag -f <file> -t <title> -a <artist> [-l <lyrics>]`
- falls back to `eyeD3 --title --artist --add-lyrics` when `mtag` is unavailable or when the rename must be skipped
- skips the rename (calling `eyeD3` directly) when the target `<title>.mp3` already exists or is already the current filename, so nothing is overwritten
- sanitizes `/` in a title to `-`
- only ever applies `OK` rows; `ASK`/`SKIP`/`UNSUPPORTED` are reported and left untouched
- deletes staged `.mtag-lyrics/` files only after their row embedded and verified them, then removes the directory if it is empty. Files you point `LYRICS` at outside `.mtag-lyrics/` are never touched.

## Phase 6 — Verify and report

`apply.sh` re-reads every written file with `ffprobe` and fails a row when the title/artist does not match, or when lyrics were requested but no `lyrics-*` tag exists. Report from its output:

- the old → new filename map for renamed files
- title/artist actually written, and whether lyrics were embedded
- rows that failed, with the error
- rows skipped and why

Do not claim success for a row that reported `ERROR`, and never describe lyrics as embedded based on `lyrics.sh` alone — only on `apply.sh`'s readback.

## Risks and limits

- **MP3 only, for tagging.** `ffprobe` can read tags from flac/m4a/wav, but `mtag`/`eyeD3` cannot write them. Mark non-`.mp3` files `UNSUPPORTED` rather than attempting.
- **`mtag` overwrites on rename.** Its final step is a plain `mv` to `<title>.mp3`. `apply.sh` pre-checks the target to avoid destroying an existing file; never bypass that check by calling `mv` yourself.
- **Duplicate titles.** Two files normalizing to the same title both want `<title>.mp3`. The second one gets tags without a rename. Surface this to the user instead of renaming around it.
- **A `|` in a value shifts the row.** Pipes inside a filename, title, or artist would be read as cell separators. Emit those rows as `ASK` with the reason in `NOTE`; never hand back an `OK` row that would be misparsed. Tabs are harmless now — cells split on `|` only.
- **Malformed rows fail loudly.** A row without exactly seven cells is reported as `ERROR` and the run exits non-zero; it is never applied or silently skipped, so a hand-edited table cannot half-apply by accident.
- **Lyrics coverage is partial.** LRCLIB had 20 results for `Enrique Iglesias / Why Not Me` but **zero** for `Laura Benanti / Someone You Loved`, and a duration filter rejected a 30s clip of a 4-minute track. Covers, live versions, remixes, and non-mainstream catalogs routinely miss. `none` is a normal outcome, not a failure — say so and move on.
- **Never fabricate lyrics.** No writing lyric text from memory, no matching on title alone, no picking the first search hit. Only a candidate within 3s of the file's duration and with a normalized exact title match is a `match`.
- **Synced lyrics are deliberately ignored.** LRCLIB returns LRC with timestamps, but USLT has no timing, so embedding LRC text would store literal `[00:12.34]` lines in the tag. Only `plainLyrics` is embedded.
- **Lyrics staging is disposable.** `apply.sh` deletes `.mtag-lyrics/` files after a row embeds and verifies them, so an applied+renamed row cannot be re-applied without re-running `lyrics.sh` (one LRCLIB call, or `cached` if the file is still staged).
- **Fetching is on by default.** Every accepted run makes one LRCLIB request per `OK` row, so tell the user up front (Phase 4) and skip the step when they ask for tags only. A run with no network still tags everything — lyrics just come back as per-row `error`.
- **Network failure is row-local.** A `curl`/timeout error on one row reports `error` for that row; the other rows still fetch and apply. Never treat a failed fetch as a match, and never abort tagging because lyrics failed.
- **Idempotence.** Re-running an applied proposal is safe but noisy: rows whose file was renamed away report `missing file`, rows already carrying the target name are tagged in place without a second rename. Never present a re-run as a fresh success.
- **No rolling back.** Renames are plain `mv`; there is no undo. Keep the proposal file until the user has checked the result — it is the only record of the old→new mapping.

## Not covered

Cover art (`mtag -i <image>:FRONT_COVER`) and the lyrics *description*/*language* suffix (`eyeD3 --add-lyrics <file>:<description>:<lang>`) are not part of the proposal format — the `LYRICS` cell is a plain path only. If the user asks for either, run `mtag` for those files by hand and report what you passed.
