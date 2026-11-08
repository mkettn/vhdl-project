# vhdl-project

Template for a modern VHDL-2008 project with [VUnit](https://vunit.github.io/)
testbenches, runnable with the open-source [GHDL](https://github.com/ghdl/ghdl)
simulator and checked in CI on every push.

## Layout

```
run.py                      VUnit runner for all projects
requirements.txt            Python dependencies (VUnit)
.github/workflows/ci.yml    CI: runs the full test suite
projects/
  <name>/
    src/                    synthesizable sources
    tb/                     testbenches and simulation-only packages
```

Every directory in `projects/` is compiled into its own VHDL library named
after the directory, so designs refer to their own units through `work.`.
Adding a new project is just creating `projects/<name>/{src,tb}`; `run.py`
picks it up automatically. Generic sweeps or other per-testbench settings go
into a `configure_<name>` hook in `run.py`.

## Sample projects

| Project      | What it is | Testbench highlights |
|--------------|------------|----------------------|
| `blinky`     | Toggles an LED at `BLINK_FREQ_HZ` from a `CLK_FREQ_HZ` clock. | Measures the toggle period; run with two generic configurations. |
| `uart_echo`  | 8N1 UART receiver + transmitter joined through a small FIFO; echoes every received byte. | Uses VUnit's `uart_master`/`uart_slave` verification components and stream interface; OSVVM random data; swept over two baud rates. |
| `axi_rot13`  | ROT13 device (`rot13`, built from one `rot13_char` per byte) plus its AXI4-Lite embedding (`axi_rot13`): write 4 characters to `DATA_IN`, read their ROT13 from `DATA_OUT`. | Unit test of the bus-agnostic `rot13` device; AXI-level test with VUnit's `axi_lite_master` VC checking byte strobes, SLVERR responses and all 256 byte values against an independent reference model. |

### `axi_rot13` structure

```
axi_rot13            AXI4-Lite slave: handshakes, DATA_IN register, decode
└── rot13            the device: bus-agnostic, NUM_BYTES wide, combinational
    └── rot13_char   one per byte lane
```

The register map constants live in `axi_rot13_pkg`. The device itself has no
knowledge of the bus, so it can be embedded behind Avalon, Wishbone or a
stream interface the same way.

### `axi_rot13` register map

| Offset | Name       | Access | Description |
|--------|------------|--------|-------------|
| `0x0`  | `DATA_IN`  | RW     | Input word, byte `n` = character `n`. Byte strobes honoured. |
| `0x4`  | `DATA_OUT` | RO     | ROT13 of each byte of `DATA_IN`; non-letters pass through. |
| `0x8`  | `ID`       | RO     | `0x524F5431` (`"ROT1"`). |

Writes to read-only registers and accesses to unmapped offsets respond with
`SLVERR`.

## Getting started

Requirements: Python 3.9+ and GHDL (4.x recommended). On Debian/Ubuntu:

```bash
sudo apt-get install ghdl
```

```bash
python -m venv .venv && . .venv/bin/activate
```

```bash
pip install -r requirements.txt
```

Run all tests (in parallel):

```bash
python run.py -p 4
```

Other useful invocations:

```bash
python run.py --list
```

```bash
python run.py "uart_echo.*"
```

```bash
python run.py --gui "blinky.tb_blinky.*led_toggles_with_expected_period"
```

`--gui` opens the waveform in GTKWave (must be installed). Simulation output
lands in `vunit_out/`, which is git-ignored.

## CI

`.github/workflows/ci.yml` runs the full suite on every push and pull request.
`tools/xunit_summary.py` turns VUnit's xunit report into a pass/fail table on
the workflow run's summary page, and adds an error annotation (with the
failing check's message) for every failed test. To see the same table
locally:

```bash
python run.py -p 4 --xunit-xml test_results.xml; python tools/xunit_summary.py test_results.xml
```
