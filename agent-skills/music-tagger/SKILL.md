---
name: music-tagger
description: Use when a folder of audio files has missing or unusable metadata and filenames must be turned into ID3 tags. Scans the folder, proposes title/artist per file in a reviewable Markdown table, and after the user accepts, applies the tags and embeds lyrics fetched from LRCLIB plus any cover images the user supplies.
allowed-tools: Read, Write, Glob, Bash(zsh:*), Bash(ffprobe:*), Bash(jq:*), Bash(eyeD3:*), Bash(curl:*), Bash(date:*), Bash(stat:*)
---

# Music Tagger

Turn messy filenames into MP3 tags: scan → analyze → propose → gather lyrics and covers → **stop** → apply only on explicit acceptance → verify. Lyrics are fetched and embedded by default; a tags-only run is the opt-out. Cover art is embedded only from image files the user supplies — never fetched.

Tagging is done by the user's `mtag` zsh function. Do not invent a second tagger; `apply.sh` already sources and calls it.

Skill directory (from the load header, also addressable as `skill://music-tagger`): `zsh <skill-dir>/scripts/{scan,lyrics,images,apply}.sh`. Those scripts share `scripts/lib.zsh`; never re-implement proposal parsing inline.

## Phase 1 — Scan

```bash
zsh <skill-dir>/scripts/scan.sh "<folder>"
```

Add `--recursive` only if the user wants subfolders included. Scan output is TSV — that is `scan.sh`'s own machine format, not the proposal; only the proposal is Markdown. Columns are `FILE EXT TITLE ARTIST DURATION SIZE`, with `FILE` relative to the `# dir:` line. The header also carries `# images: <n>` and one `# image: <relative path>` line per image file found (`jpg/jpeg/png/webp`) — those are the candidate covers for Phase 4b.

If the folder yields zero audio files, say so and stop.

## Phase 2 — Analyze each row

Work from `FILE` plus whatever `TITLE`/`ARTIST` already exist. The goal is only to fill what is missing or obviously wrong.

Strip noise from the basename:

- bracketed suffixes: `[Official Audio]`, `(Lyrics)`, `(HD)`, `[MV]`, `(Official Video)`, `[4K]`
- cover markers a previous run wrote: `(Lewis Capaldi origin)` in an artist, and any `(... cover)` left in an older title — strip them and keep the bare song/performer when re-analyzing
- quality/bitrate tokens: `320kbps`, `128 kbps`, `HQ`, `HD`, `FLAC`, `MP3`
- separators and filler: `_`, `www.*` domains, ` - Topic`, yt-dlp video IDs (11-char `[A-Za-z0-9_-]` tail)

Then split what remains on the first strong separator: ` - `, ` – `, ` — `, `_-_`, `|`, `~`.
Decide which side is title and which is artist. `Artist - Title` is the yt-dlp convention and the most common shape, but `Title - Artist` does occur; use casing, known artist naming, and the rest of the folder (a repeated leading segment is almost always the artist) as evidence.

### Covers

When the recording is a cover, mark the artist cell only — this is the requested shape:

```
TITLE  = Someone You Loved
ARTIST = Laura Benanti (Lewis Capaldi origin)
```

- `TITLE` stays the plain song name — no marker, nothing that could read as a claim about the recording.
- `ARTIST` = `<performer> (<original artist> origin)`: the performer you group by, plus whose song it originally is.
- Exactly that wording: lowercase `origin` inside the parentheses, one space before `(`, no padding inside.
- **Only when both are defensible.** The cover performer usually comes from the filename. The original artist is knowledge, not extraction — if you cannot identify it with confidence, do not invent one: leave `ARTIST` plain and say "cover, original artist unidentified" in `NOTE`. Never guess an original from a similar-sounding title.
- Only for genuine covers. A remix, a live version, an acoustic take, or a different mix by the same artist is not a cover — never use the `origin` marker for those.
- The marker is part of the tag value, so `ARTIST` is not a bare name for players, scrobblers, or grouping. Because `TITLE` is clean, the filename stays clean too (`mtag` renames to `<title>.mp3`).
- `lyrics.sh` strips `(... origin)` before querying LRCLIB — and uses it as the fallback lookup key — while the analysis above strips it when re-reading an already-decorated artist, so the marker never breaks matching.

Hard rules:

- **Never invent metadata.** No guessed album names, no "the artist is probably X". If the split is not defensible, emit `ASK` with `?` and let the user fill it in.
- Never emit tag fields outside title and artist. The `mtag` function has no album, track, genre, or year support. (`LYRICS` and `IMAGE` are file paths, not tag fields — see Phase 3.)
- `-` means "leave this field unchanged". Never use `-` as a literal value.
- If a file already has both title and artist **and there is nothing else to add** (no lyrics, no cover), use `SKIP`. If lyrics or a cover are still missing, keep the row `OK` and put `-` in `TITLE`/`ARTIST` so the remaining columns can be applied without rewriting tags that are already correct.

## Phase 3 — Write the proposal

Write `<folder>/mtag-proposal.md` — a Markdown file the user reads and edits: a short header, then one table row per file.

```md
# music-tagger proposal

- dir: /absolute/folder/path
- generated: 2026-09-13T17:20:00
- apply: `zsh <skill-dir>/scripts/apply.sh "<this file>" --yes`

| STATUS | FILE | TITLE | ARTIST | LYRICS | IMAGE | CONF | NOTE |
| --- | --- | --- | --- | --- | --- | --- | --- |
| OK | 01 - Song Name_[Official Audio]_320kbps.mp3 | Song Name | Real Artist | - | - | high | dropped [Official Audio], 320kbps |
| OK | Real Artist - Track Name (HD).mp3 | Track Name | Real Artist | .mtag-lyrics/real-artist-track-name.txt | covers/track-name.jpg | high | artist-first split |
| OK | Someone You Loved - Laura Benanti.mp3 | Someone You Loved | Laura Benanti (Lewis Capaldi origin) | - | covers/benanti.jpg | medium | cover of Lewis Capaldi |
| ASK | unknown_1.mp3 | ? | ? | - | - | low | no separable title or artist |
| SKIP | already-tagged.mp3 | - | - | - | - | - | has title and artist already |
```

- `OK` — apply these values. At least one of `TITLE`/`ARTIST`/`LYRICS`/`IMAGE`.
- `ASK` — needs a human decision; never applied.
- `SKIP` — deliberately left alone.
- `UNSUPPORTED` — not an MP3 (see risks).

`LYRICS` holds a **path** to a plain-text lyrics file — relative to the folder, absolute also accepted — or `-` for none. Lyric text is never written into the proposal: a Markdown table row cannot contain newlines, so inlining even one lyric would destroy the table. Write `-` when you create the proposal and leave the cell alone; Phase 4 fills it in.

`IMAGE` holds a **path** to a cover image the user supplied — relative to the folder, absolute also accepted — or `-` for none. Rules:

- **Only images the user gave you.** Never search the web, never download a cover, never generate one, never pick an image out of the blue because a filename looked suggestive. Files already on disk that the user pointed at, or explicitly mentioned, are the only valid sources.
- Embedded as `FRONT_COVER`, one image per file. There is no type suffix: a `:` anywhere in the path is rejected by `apply.sh`.
- Extensions: `jpg`, `jpeg`, `png`, `webp`.
- Never index images by row number or list order. If you are mapping several loose images to rows, match them by normalized title/artist and write the paths in — the mapping must stay visible in the table so it can be reviewed. If a mapping is not defensible, use `ASK`.
- If a file already carries cover art and the user did not ask to replace it, use `-` and say so in `NOTE`; `apply.sh` reports when an attach replaced an existing cover.
- Note oversized images in `NOTE`: embedded art lives inside every audio file, so prefer roughly ≤1000px and <1MB.

Format rules:

- Exactly eight cells per row, in the column order above. `apply.sh` rejects a row with the wrong cell count rather than guessing.
- `TITLE`, `ARTIST`, and `NOTE` may contain spaces; do not quote cells and do not pad them for alignment — padding is trimmed either way, so write plain unaligned rows.
- A literal `|` inside any value would split the row. Emit such a row as `ASK` with the reason in `NOTE` instead of an `OK` row.
- Only table rows are read. Title lines, bullets, blank lines, and anything else in the file are ignored, so the header block can be written freely.
- `CONF` is `high|medium|low`. `NOTE` is one short reason: which noise was dropped, how the split was decided, or why it is `ASK`.

Copy `FILE` values verbatim from scan output. Never rename, reorder, or normalize them; only `TITLE`/`ARTIST` are meant to be edited.

`mtag` renames the file to `<title>.mp3` in the same folder, so state the resulting filename for each `OK` row when you report.

## Phase 4 — Gather lyrics and covers (before the review)

Everything that can be attached is resolved **before** you stop, so the user reviews one complete table — titles, artists, lyrics, covers — in a single pass.

### 4a. Lyrics — always, unless the user opted out

Run this for every proposal. Skip it only when the user asked for tags only (`--no-lyrics`, "no lyrics", "just tags").

```bash
zsh <skill-dir>/scripts/lyrics.sh "<folder>/mtag-proposal.md"   # add --force to refetch staged files
```

It queries LRCLIB per `OK` row (artist + title), keeps candidates within 3s of the file's own duration, prefers a normalized exact title match, writes the plain lyrics to `<folder>/.mtag-lyrics/<artist>-<title>.txt`, and prints one line per row. An `origin` marker is stripped before the query — `Laura Benanti (Lewis Capaldi origin)` is looked up as `Laura Benanti`, and the staged filename uses the bare name.

**Origin fallback.** When the performer's own lookup finds no match and the `ARTIST` cell carries an `origin`, the query is retried against the original artist — usually the only version LRCLIB has. The retry demands a normalized exact title plus a matching artist, applies **no duration gate** (a cover's length often differs a lot) and takes the closest duration; the detail line says `(via original <name>)`, e.g.

```
LYRICS	Someone You Loved - Laura Benanti.mp3	.mtag-lyrics/laura-benanti-someone-you-loved.txt	match	[20 raw, 20 any duration] Someone You Loved - Lewis Capaldi 186.0s, diff 0s (via original Lewis Capaldi)
```

If the closest exact-title candidate is more than 120s off the file, the fallback reports `ambiguous` instead of matching, so a clip or a radically different version is never silently given the original's lyrics:

```
LYRICS <TAB> FILE <TAB> PATH|- <TAB> STATUS <TAB> DETAIL
```

- `match` — patch that row's `LYRICS` cell with `PATH` (as printed, relative to the folder).
- `cached` — a usable file is already staged; patch the cell with `PATH`.
- `ambiguous` — candidates matched but the title was not exact. Leave `-` and tell the user what was found; never guess a lyric source.
- `none` — leave `-`. This is normal for covers, live takes, and non-mainstream catalogs.
- `error` — network or IO failure for that row; leave `-`, report it, and continue. Do not abort the whole run.

Patch only the `LYRICS` cells — the column is 5th. Do not reorder, rewrap, or re-align other cells, and never paste lyric text into the table. Repeat the `MATCH`/`cached` paths and the notable `DETAIL` lines when you report at the stop, so the user can catch a wrong match — especially a `(via original …)` one — before anything is written.

### 4b. Covers — from images you actually have

Never fetch, download, or generate a cover. Work only from image files that scan reported (`# image: …`) or that the user handed you.

**Auto-fill rule.** If the number of available images equals the number of `OK` rows whose `IMAGE` cell is empty or `-`, map them positionally — that match is the evidence they belong together:

```bash
zsh <skill-dir>/scripts/images.sh "<folder>/mtag-proposal.md" "<image-dir>"         # dry run: prints the mapping
zsh <skill-dir>/scripts/images.sh "<folder>/mtag-proposal.md" "<image-dir>" --yes   # writes the paths into the table
```

Use the folder itself as `<image-dir>` when the images sit beside the audio. Ordering: names that are entirely digits sort first, numerically (`1.jpg, 2.jpg, … 10.jpg`); everything else sorts after them lexicographically.

**Positional means position *now*.** The pairing is numeric-image order against the current row order, so it is only as stable as the listing it was taken from. A previous run that renamed files to `<title>.mp3` re-sorts the folder alphabetically and can invert a numbering you prepared earlier — a real case: images numbered `1.png, 2.png` against `Enrique Iglesias - Why Not Me…mp3` / `Someone You Loved - Laura Benanti.mp3`, then the files renamed to `Someone You Loved.mp3` / `Why Not Me.mp3`, which reverses the anchor. Therefore:

- Always state the anchor in the stop report — `1.png → Why Not Me.mp3` — never just "covers mapped".
- When a cover carries readable artist/title text, trust the artwork over the position and correct the mapping (including filling cells by hand).
- When the mapping cannot be checked from the images themselves, say which part is positional and let the user confirm before applying.

**Counts do not match → do not guess.** Report what you found and ask. Three cases:

- More images than rows: they may be extras, or the mapping may be by name — ask, or fill cells yourself when the names clearly match the tracks.
- Fewer images than rows: it may be one shared cover (`cover.jpg` for the whole folder). That is the user's call, not yours — they write the same path into several cells, or tell you which image goes where.
- No images at all: leave every `IMAGE` cell as `-`. Never attach something speculative.

Other rules:

- `ASK`/`SKIP` rows are never filled, and rows that already have an `IMAGE` path are left alone.
- Paths are written relative when the image lives inside the folder, absolute otherwise. A number is never stored in the table, so later row edits cannot silently re-point a cover.
- One image per file, always `FRONT_COVER`; attaching over an existing cover replaces it and the run says so. `jpg/jpeg/png/webp` only, and no `:` anywhere in the path.
- Show the mapping at the stop so it is reviewed with everything else.

## Phase 5 — Stop for review

Print the proposal path, the per-status counts, the list of `OK` rows with their resulting filenames, the lyrics outcome per row (`match`/`none`/`ambiguous`, including any `via original`), and the image mapping. Then stop and wait. Never run `mtag` or `apply.sh --yes` before the user accepts.

This is the single gate: lyrics and covers are already in the table by now, so nothing else is fetched after acceptance. The user accepts by editing the table in place and saying go. Re-read the file after acceptance; do not reuse values you had in memory.

## Phase 6 — Apply

```bash
zsh <skill-dir>/scripts/apply.sh "<folder>/mtag-proposal.md"        # prints WOULD lines, writes nothing
zsh <skill-dir>/scripts/apply.sh "<folder>/mtag-proposal.md" --yes  # executes
```

`apply.sh` handles the mechanics so they are identical every run:

- sources `~/.aliases/media/tag-audio.sh` and calls `mtag -f <file> -t <title> -a <artist> [-l <lyrics>] [-i <image>]`
- falls back to `eyeD3 --title --artist --add-lyrics --add-image <image>:FRONT_COVER` when `mtag` is unavailable or when the rename must be skipped
- skips the rename (calling `eyeD3` directly) when the target `<title>.mp3` already exists or is already the current filename, so nothing is overwritten
- sanitizes `/` in a title to `-`, rejects a `:` or a non-`jpg/jpeg/png/webp` extension in an image path
- only ever applies `OK` rows; `ASK`/`SKIP`/`UNSUPPORTED` are reported and left untouched
- deletes staged `.mtag-lyrics/` files only after their row embedded and verified them, then removes the directory if it is empty. Files you point `LYRICS` or `IMAGE` at are never deleted.

## Phase 7 — Verify and report

`apply.sh` re-reads every written file with `ffprobe` and fails a row when the title/artist does not match, when lyrics were requested but no `lyrics-*` tag exists, or when an image was requested but no attached-picture stream is present. Report from its output:

- the old → new filename map for renamed files
- title/artist actually written, whether lyrics were embedded, whether a cover was attached (and if it replaced an existing one)
- rows that failed, with the error
- rows skipped and why

Do not claim success for a row that reported `ERROR`, and never describe lyrics or cover art as embedded based on `lyrics.sh` or on having passed a path — only on `apply.sh`'s readback.

## Risks and limits

- **MP3 only, for tagging.** `ffprobe` can read tags from flac/m4a/wav, but `mtag`/`eyeD3` cannot write them. Mark non-`.mp3` files `UNSUPPORTED` rather than attempting.
- **`mtag` overwrites on rename.** Its final step is a plain `mv` to `<title>.mp3`. `apply.sh` pre-checks the target to avoid destroying an existing file; never bypass that check by calling `mv` yourself.
- **Duplicate titles.** Two files normalizing to the same title both want `<title>.mp3`. The second one gets tags without a rename. Surface this to the user instead of renaming around it.
- **A `|` in a value shifts the row.** Pipes inside a filename, title, or artist would be read as cell separators. Emit those rows as `ASK` with the reason in `NOTE`; never hand back an `OK` row that would be misparsed. Tabs are harmless now — cells split on `|` only.
- **Malformed rows fail loudly.** A row without exactly eight cells is reported as `ERROR` and the run exits non-zero; it is never applied or silently skipped, so a hand-edited table cannot half-apply by accident.
- **Cover art comes only from the user.** No web search, no download, no generated placeholder, no "that filename looks like an album so this artwork probably fits". Offer to fill the `IMAGE` column only from files the user supplied or pointed at, and mark anything you cannot map defensibly as `ASK`.
- **One image, `FRONT_COVER`, replaced not accumulated.** Attaching a cover to a file that already has one overwrites the existing front cover (verified: still exactly one attached-picture stream). Say so when it happens. A `:` in the image path is a hard `ERROR`, because `mtag` builds `--add-image <path>:FRONT_COVER`.
- **The origin marker lives in `ARTIST`.** `Laura Benanti (Lewis Capaldi origin)` is what players, scrobblers, and library grouping see and sort on — the title stays clean, but the artist string is not a bare identity. The skill strips the marker for lyric lookup; other tools will not. Prefer no decoration when the user hasn't asked for it, and never invent an `origin` to fill the pattern.
- **Numbers never enter the table.** A positional `IMAGE` value would re-point every cover the moment a row is added, removed, reordered, or flipped to `SKIP`. Numbered input files are fine; `images.sh` resolves them to explicit paths once, and refuses to act at all when the counts disagree.
- **Embedded art adds weight.** A 5MB JPEG is copied into every track it is attached to. Prefer ≤1000px and <1MB, and mention the size in `NOTE` when it is far over.
- **The origin fallback can attach the original's text to a re-written cover.** Lyrics are normally identical across versions, but a cover with altered verses or added ad-libs will get the original's words. The `(via original …)` label plus the duration diff in DETAIL is the tell — read those lines before accepting, and blank the cell if a row looks wrong.
- **Lyrics coverage is partial.** LRCLIB had 20 results for `Enrique Iglesias / Why Not Me` but **zero** for `Laura Benanti / Someone You Loved`, and a duration filter rejected a 30s clip of a 4-minute track. Covers, live versions, remixes, and non-mainstream catalogs routinely miss. `none` is a normal outcome, not a failure — say so and move on. The origin fallback rescues part of that gap, not all of it: it needs an `origin` marker to work from.
- **Never fabricate lyrics.** No writing lyric text from memory, no picking the first search hit, no matching on title alone. A `match` requires a normalized exact title and either a duration within 3s of the file (performer lookup) or an exact artist plus the 120s guard (origin fallback).
- **Synced lyrics are deliberately ignored.** LRCLIB returns LRC with timestamps, but USLT has no timing, so embedding LRC text would store literal `[00:12.34]` lines in the tag. Only `plainLyrics` is embedded.
- **Lyrics staging is disposable.** `apply.sh` deletes `.mtag-lyrics/` files after a row embeds and verifies them, so an applied+renamed row cannot be re-applied without re-running `lyrics.sh` (one LRCLIB call, or `cached` if the file is still staged).
- **Fetching is on by default and happens before the review.** Every run makes one LRCLIB request per `OK` row, so the lyrics outcome is part of what the user reviews at the stop, not a surprise afterwards. Skip the step only when they ask for tags only. A run with no network still tags everything — lyrics just come back as per-row `error`.
- **Network failure is row-local.** A `curl`/timeout error on one row reports `error` for that row; the other rows still fetch and apply. Never treat a failed fetch as a match, and never abort tagging because lyrics failed.
- **Idempotence.** Re-running an applied proposal is safe but noisy: rows whose file was renamed away report `missing file`, rows already carrying the target name are tagged in place without a second rename. Never present a re-run as a fresh success.
- **No rolling back.** Renames are plain `mv`; there is no undo. Keep the proposal file until the user has checked the result — it is the only record of the old→new mapping.

## Not covered

The lyrics *description*/*language* suffix (`eyeD3 --add-lyrics <file>:<description>:<lang>`) and non-`FRONT_COVER` image types (`mtag -i` hardcodes the type) are not part of the proposal format — the `LYRICS` and `IMAGE` cells are plain paths only. If the user asks for one of those, run `mtag` for those files by hand and report what you passed.
