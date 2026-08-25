# Patches for external Klin packages

Apply against the named upstream repo when the cloud agent cannot push
there. New packages that cannot be created under `klin-lang/*` yet live
as a **seed tree** (copy into a new empty repo, then tag).

| Patch / seed | Upstream | Klin issue |
|---|---|---|
| [machine_avr-v0.3.0-atmega32u4.patch](machine_avr-v0.3.0-atmega32u4.patch) | [`klin-lang/machine_avr`](https://github.com/klin-lang/machine_avr) **merged** → [`v0.3.0`](https://github.com/klin-lang/machine_avr/releases/tag/v0.3.0) | [142](../issues/142-machine-avr-atmega32u4.md) ✅ |
| [klin_xpt2046-v0.1.0/](klin_xpt2046-v0.1.0/) | [`klin-lang/klin_xpt2046`](https://github.com/klin-lang/klin_xpt2046) (create empty repo, copy seed, tag `v0.1.0`) | [149](../issues/149-klin-xpt2046.md) 🔨 |

```sh
cd /path/to/machine_avr
git checkout main && git pull
git apply /path/to/klin/patches/machine_avr-v0.3.0-atmega32u4.patch
```

```sh
# New package seed (no upstream yet):
cp -a patches/klin_xpt2046-v0.1.0/. /path/to/klin_xpt2046/
cd /path/to/klin_xpt2046
# git init / remote / tag v0.1.0
klin test klin_xpt2046
```
