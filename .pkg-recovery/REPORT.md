# Package recovery report

Source transcript:
`/tmp/cursor/cloud-agent-transcripts/2026-08-16T02-48-09Z-1c81/bc-a9ea96be-fe84-490f-af7c-6cbecacfdfe6/transcript.json`

## Method

1. Loaded transcript messages and collected every Cursor `search_replace` `diffString` whose path mentioned `/tmp/gd32v_sockets` or `/tmp/gd32v_http` (33 patches, applied in order).
2. Recovered `LICENSE` and `.gitignore` from `/tmp/gd32v_wifi` create diffs (the agent `cp`’d those into both package trees; no separate Write for them under `/tmp/gd32v_*`).
3. Validated against the agent’s `git commit` summaries (`13 files`, **903** / **975** insertions) — recovered line totals match exactly.

No `# RECOVERY INCOMPLETE` stubs were required.

## Trees

### gd32v_sockets (13 files)

| Path | Bytes |
|---|---:|
| `.gitignore` | 38 |
| `LICENSE` | 1061 |
| `README.md` | 3020 |
| `examples/smoke/Makefile` | 434 |
| `examples/smoke/smoke.kl` | 1032 |
| `examples/tcp_client/Makefile` | 486 |
| `examples/tcp_client/tcp_client.kl` | 687 |
| `gd32v_sockets/sock.kl` | 3691 |
| `gd32v_sockets/sock_sdk.c` | 8528 |
| `gd32v_sockets/sock_sdk.h` | 1813 |
| `gd32v_sockets/sock_test.kl` | 1872 |
| `gd32v_sockets/version.kl` | 61 |
| `gd32v_sockets/version_test.kl` | 366 |

### gd32v_http (13 files)

| Path | Bytes |
|---|---:|
| `.gitignore` | 38 |
| `LICENSE` | 1061 |
| `README.md` | 2960 |
| `examples/http_get/Makefile` | 463 |
| `examples/http_get/http_get.kl` | 442 |
| `examples/smoke/Makefile` | 425 |
| `examples/smoke/smoke.kl` | 697 |
| `gd32v_http/http.kl` | 2412 |
| `gd32v_http/http_sdk.c` | 16266 |
| `gd32v_http/http_sdk.h` | 1195 |
| `gd32v_http/http_test.kl` | 990 |
| `gd32v_http/version.kl` | 58 |
| `gd32v_http/version_test.kl` | 173 |

## Notes

- Some mid-run `read_file` payloads in the transcript are truncated or pre-edit snapshots (e.g. `http_sdk.h` before its later patch; `README.md` contents starting mid-fence). Final recovered text comes from the full ordered `diffString` chain, not those reads.
- Post-commit amend of `gd32v_http/README.md` (truncation / status wording) is included.
- Original `/tmp/gd32v_*` trees and `/opt/cursor/artifacts/*gd32v*-v0.1.0.bundle` were not present in this environment.

## Incomplete files

- none

## Publish readiness (v0.1.0)

**Yes — complete enough to publish v0.1.0.** Layout matches the agent’s tagged trees (Klin package dirs, examples, LICENSE, README, `.gitignore`, `.kl` / `.c` / `.h`), line counts match the initial commits, and the late HTTP README amend is present.
