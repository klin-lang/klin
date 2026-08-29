# Smoke (stubs)

`make emit` runs Klin `--emit-c` against the real `espnow` module. The
`@[link("now_idf.c")]` unit is the package C file; for host compile without IDF
use `stubs/` as a reference — full link needs ESP-IDF (see `examples/peer_s3/`).
