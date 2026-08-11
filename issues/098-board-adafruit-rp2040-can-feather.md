# 098 — Board pack: Adafruit RP2040 CAN Bus Feather

**Status:** ✅ published `@v0.1.0`  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [075](075-board-pack-init-host.md), [010](010-bare-metal.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/adafruit_rp2040_can_feather`](https://github.com/klin-lang/adafruit_rp2040_can_feather) `@v0.1.0` |
| Chip API | [`machine_rp`](https://github.com/klin-lang/machine_rp) `@v0.11.0` (Spi + Pin + Uart) |
| Board extras | Feather pin map + **MCP25625** SPI driver (MCP2515 + transceiver) + examples |

## Why not `machine_rp.Can`?

RP2040 has **no on-chip CAN**. The Feather uses an external SPI controller
(MCP25625). Same policy as DAC/PIO in [061](061-micropython-machine-api.md):
do not fake a silicon peripheral. On-chip CAN (STM32 bxCAN / ESP TWAI) is a
separate future `machine_*.Can` track.

## Scope (`@v0.1.0`)

- Pins: LED D13, UART0, SPI1 CAN (GP14/15/8), CS/INT/STBY/RESET/…
- `mcp2515.kl`: soft NSS, 500 kbit/s @ 16 MHz OSC, standard 11-bit ID,
  loopback / normal modes, TXB0 / RXB0
- Examples: `blink`, `can_loopback`, `can_tx`, `can_rx`
- Pico-class freestanding startup + boot2

## Usage

```klin
import "github/klin-lang/machine_rp" machine
import "github/klin-lang/adafruit_rp2040_can_feather" board

@[link("startup.s")]
@[link("boot2_w25q080.S")]
fn main() {
  let can = board.can_out(1) // loopback
  let f = board.CanFrame{
    id: 0x123, len: 1,
    d0: 0x42, d1: 0, d2: 0, d3: 0, d4: 0, d5: 0, d6: 0, d7: 0
  }
  let _ = can.send_std(0x123, 1, f)
}
```

```sh
klin get github/klin-lang/adafruit_rp2040_can_feather@v0.1.0
klin get github/klin-lang/machine_rp@v0.11.0
```

## Links

- Repo: https://github.com/klin-lang/adafruit_rp2040_can_feather  
- Tag: [v0.1.0](https://github.com/klin-lang/adafruit_rp2040_can_feather/releases/tag/v0.1.0)
- Product: [Adafruit 5724](https://www.adafruit.com/product/5724) /
  [Botland](https://botland.com.pl/magistrala-can/23378-rp2040-can-bus-feather-modul-can-bus-z-mikrokontrolerem-rp2040-mcp2515-stemma-qt-adafruit-5724.html)
- Learn: https://learn.adafruit.com/adafruit-rp2040-can-bus-feather
- Sibling packs: [095](095-board-waveshare-rp2350-lcd-096.md), [096](096-board-nucleo-f411re.md)
