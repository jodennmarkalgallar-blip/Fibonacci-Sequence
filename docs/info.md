## How it works

Two 3-digit BCD registers hold consecutive Fibonacci numbers `a = F(n)` and `b = F(n+1)`.
Each step does `a <= b; b <= a + b` using a digit-by-digit BCD adder (add, and if a digit
exceeds 9 add 6 and carry), so no binary-to-BCD converter is needed.

The sequence shown is `0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987`, then it wraps to `0`.
987 is the largest Fibonacci number not above 1000 (the next one, 1597, needs four digits).

A free-running 14-bit prescaler scans the three digits (`cnt[1:0]`, the fourth slot is
all-off dead time) and also provides the auto-run tick. Leading zeros are blanked.

## How to test

1. Pull `rst_n` low, then high: display shows `0`.
2. Pulse `ui[0]` (STEP) to advance one Fibonacci number, or set `ui[1]` (RUN) high to free-run.
   `ui[3:2]` chooses the step period: 2^11, 2^12, 2^13, 2^14 clocks (about 0.2 / 0.4 / 0.8 / 1.6 s at 10 kHz).
3. At 987 the `uio[3]` MAX flag goes high; the next step wraps back to 0.

The scan rate is `clk/4` per digit, so use a clock of roughly 1 kHz to 1 MHz for a flicker-free display.

## External hardware

A 3-digit common-cathode 7-segment display: segments a..g on `uo[0..6]`, digit cathodes on
`uio[0..2]` (active low, so drive them through a transistor or use a driver board if the display draws
more than a few mA per digit).
