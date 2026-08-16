# Patches for external Klin packages

Apply against the named upstream repo when the cloud agent cannot push
there.

| Patch | Upstream | Klin issue |
|---|---|---|
| [machine_avr-v0.3.0-atmega32u4.patch](machine_avr-v0.3.0-atmega32u4.patch) | [`klin-lang/machine_avr`](https://github.com/klin-lang/machine_avr) **merged** → [`v0.3.0`](https://github.com/klin-lang/machine_avr/releases/tag/v0.3.0) | [142](../issues/142-machine-avr-atmega32u4.md) ✅ |

```sh
cd /path/to/machine_avr
git checkout main && git pull
git apply /path/to/klin/patches/machine_avr-v0.3.0-atmega32u4.patch
```
