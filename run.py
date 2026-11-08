#!/usr/bin/env python3
"""VUnit test runner for all projects in this repository.

Every directory below ``projects/`` is compiled into its own VHDL library
(named after the directory) from its ``src/`` and ``tb/`` folders. Testbench
specific configuration (generic sweeps etc.) lives in ``configure_*`` hooks
below.

Usage examples::

    python run.py                      # run everything
    python run.py -p 4                 # run 4 tests in parallel
    python run.py "uart_echo.*"        # run one project
    python run.py --list               # list all tests
    python run.py --gui "blinky.tb_blinky.led_toggles_with_expected_period"
"""

from pathlib import Path

from vunit import VUnit

ROOT = Path(__file__).parent
PROJECTS = ROOT / "projects"


def configure_blinky(lib):
    tb = lib.test_bench("tb_blinky")
    for clk_hz, blink_hz in [(1_000, 50), (10_000, 1)]:
        tb.add_config(
            name=f"clk={clk_hz}_blink={blink_hz}",
            generics={"CLK_FREQ_HZ": clk_hz, "BLINK_FREQ_HZ": blink_hz},
        )


def configure_uart_echo(lib):
    tb = lib.test_bench("tb_uart_echo")
    for baud in [115_200, 1_000_000]:
        tb.add_config(name=f"baud={baud}", generics={"BAUD_RATE": baud})


def configure_axi_rot13(lib):
    tb = lib.test_bench("tb_axi_rot13")
    for width in [4, 8]:
        tb.add_config(name=f"addr_width={width}", generics={"ADDR_WIDTH": width})


CONFIGURE = {
    "axi_rot13": configure_axi_rot13,
    "blinky": configure_blinky,
    "uart_echo": configure_uart_echo,
}


def main():
    vu = VUnit.from_argv(compile_builtins=False)
    vu.add_vhdl_builtins()
    vu.add_com()
    vu.add_verification_components()
    vu.add_osvvm()

    for project in sorted(p for p in PROJECTS.iterdir() if p.is_dir()):
        lib = vu.add_library(project.name)
        for sub in ("src", "tb"):
            lib.add_source_files(project / sub / "*.vhd", allow_empty=True)
        if project.name in CONFIGURE:
            CONFIGURE[project.name](lib)


    # Keep IEEE (numeric_std) warnings on: metavalue warnings are often the
    # first sign of X/U propagation. Only the time-0 ones are suppressed,
    # which come from signals that have not been driven yet.
    vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable-at-0"])

    vu.main()


if __name__ == "__main__":
    main()
