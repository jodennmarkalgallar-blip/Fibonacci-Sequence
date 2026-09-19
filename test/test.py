# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# segment pattern (uo_out[6:0], bit0 = a) -> digit; 0 = blank
SEG = {0x3F: 0, 0x06: 1, 0x5B: 2, 0x4F: 3, 0x66: 4, 0x6D: 5, 0x7D: 6, 0x07: 7, 0x7F: 8, 0x6F: 9, 0x00: None}

FIB = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]


async def read_display(dut):
    """Watch the multiplexed display for a few scan periods and rebuild the number."""
    digits = {}
    for _ in range(16):
        await ClockCycles(dut.clk, 1)
        sel = int(dut.uio_out.value) & 0b111
        seg = int(dut.uo_out.value) & 0x7F
        for pos in range(3):
            if (sel >> pos) & 1 == 0:          # active-low digit select
                assert (sel | (1 << pos)) == 0b111, "more than one digit enabled"
                digits[pos] = SEG[seg]
    assert set(digits) == {0, 1, 2}, "not all digits were scanned"
    value = 0
    for pos in (2, 1, 0):
        d = digits[pos]
        if d is not None:
            value = value * 10 + d
        elif pos == 0:
            raise AssertionError("ones digit must never be blank")
    return value


async def press_step(dut):
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 4)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 4)


async def reset(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_manual_sequence(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="us").start())
    await reset(dut)

    # two full laps to check the wrap-around 987 -> 0
    for lap in range(2):
        for i, expected in enumerate(FIB):
            got = await read_display(dut)
            assert got == expected, f"lap {lap} step {i}: display {got}, expected {expected}"
            at_max = (int(dut.uio_out.value) >> 3) & 1
            assert at_max == (1 if expected == 987 else 0)
            await press_step(dut)
    assert dut.uio_oe.value == 0x0F


@cocotb.test()
async def test_auto_run(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="us").start())
    await reset(dut)

    dut.ui_in.value = 0b0000_0010            # run, fastest speed (2048 clocks per step)
    seen = []
    for _ in range(6):
        seen.append(await read_display(dut))
        await ClockCycles(dut.clk, 2048 - 16)
    dut._log.info(f"auto-run values: {seen}")
    # exactly one step per 2048 clocks -> consecutive Fibonacci numbers
    assert seen == FIB[:6], seen
