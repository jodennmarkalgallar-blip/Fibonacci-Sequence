/*
 * Fibonacci counter, 0 .. 987 (largest Fibonacci number <= 1000)
 * SPDX-License-Identifier: Apache-2.0
 *
 * The two Fibonacci registers are kept directly in BCD (3 digits each), so
 * there is no binary->BCD converter: the value is added digit by digit and
 * the display just decodes each digit.
 *
 * Sequence shown: 0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 -> 0 ...
 */

`default_nettype none

module tt_um_fibonacci_counter (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // ---------------------------------------------------------------------
  // Free-running prescaler: bits [1:0] scan the digits, higher bits set the
  // auto-run speed.
  // ---------------------------------------------------------------------
  reg [13:0] cnt;
  always @(posedge clk) begin
    if (!rst_n) cnt <= 14'd0;
    else        cnt <= cnt + 14'd1;
  end

  // Auto-run speed select (ui_in[3:2]): rising edge of one prescaler bit.
  // A step happens every 2^(k+1) clocks for tap bit k. At a 10 kHz clock:
  // 00 -> ~0.2 s, 01 -> ~0.4 s, 10 -> ~0.8 s, 11 -> ~1.6 s per step.
  reg tap;
  always @(*) begin
    case (ui_in[3:2])
      2'd0:    tap = cnt[10];
      2'd1:    tap = cnt[11];
      2'd2:    tap = cnt[12];
      default: tap = cnt[13];
    endcase
  end

  reg tap_q;
  always @(posedge clk) tap_q <= tap;
  wire auto_tick = ui_in[1] & tap & ~tap_q;

  // Manual step button (ui_in[0]): 2-FF synchroniser + rising-edge detect.
  reg [2:0] btn_sync;
  always @(posedge clk) btn_sync <= {btn_sync[1:0], ui_in[0]};
  wire manual_tick = btn_sync[1] & ~btn_sync[2];

  wire step = manual_tick | auto_tick;

  // ---------------------------------------------------------------------
  // Fibonacci registers, BCD: a = F(n), b = F(n+1)
  // ---------------------------------------------------------------------
  reg [11:0] a, b;
  reg [11:0] sum;   // a + b in BCD (carry out of the hundreds digit is dropped)

  reg [4:0] t;
  reg       c;
  integer   i;
  always @(*) begin
    c = 1'b0;
    sum = 12'd0;
    for (i = 0; i < 3; i = i + 1) begin
      t = a[4*i +: 4] + b[4*i +: 4] + c;
      if (t > 5'd9) begin
        t = t + 5'd6;
        c = 1'b1;
      end else begin
        c = 1'b0;
      end
      sum[4*i +: 4] = t[3:0];
    end
  end

  wire at_max = (a == 12'h987);   // F(16) = 987; F(17) = 1597 would not fit

  always @(posedge clk) begin
    if (!rst_n) begin
      a <= 12'h000;
      b <= 12'h001;
    end else if (step) begin
      if (at_max) begin           // wrap around: 987 -> 0
        a <= 12'h000;
        b <= 12'h001;
      end else begin
        a <= b;
        b <= sum;
      end
    end
  end

  // ---------------------------------------------------------------------
  // 3-digit multiplexed 7-segment display (common cathode)
  //   uo_out[6:0] = segments a..g, uo_out[7] = decimal point (unused, 0)
  //   uio_out[2:0] = digit selects: ones, tens, hundreds (ACTIVE LOW)
  //   uio_out[3]   = "at maximum (987)" flag
  // Leading zeros are blanked; the 4th scan slot is all-off dead time.
  // ---------------------------------------------------------------------
  wire [1:0] scan = cnt[1:0];

  reg [3:0] digit;
  reg [2:0] sel;
  reg       blank;
  always @(*) begin
    case (scan)
      2'd0:    begin digit = a[3:0];   sel = 3'b001; blank = 1'b0;             end
      2'd1:    begin digit = a[7:4];   sel = 3'b010; blank = (a[11:4] == 8'd0); end
      2'd2:    begin digit = a[11:8];  sel = 3'b100; blank = (a[11:8] == 4'd0); end
      default: begin digit = 4'd0;     sel = 3'b000; blank = 1'b1;             end
    endcase
  end

  reg [6:0] seg;
  always @(*) begin
    case (digit)
      4'd0:    seg = 7'b0111111;
      4'd1:    seg = 7'b0000110;
      4'd2:    seg = 7'b1011011;
      4'd3:    seg = 7'b1001111;
      4'd4:    seg = 7'b1100110;
      4'd5:    seg = 7'b1101101;
      4'd6:    seg = 7'b1111101;
      4'd7:    seg = 7'b0000111;
      4'd8:    seg = 7'b1111111;
      4'd9:    seg = 7'b1101111;
      default: seg = 7'b0000000;
    endcase
  end

  assign uo_out  = {1'b0, blank ? 7'b0000000 : seg};
  assign uio_out = {4'b0000, at_max, ~sel};
  assign uio_oe  = 8'b0000_1111;

  // Avoid unused-signal warnings
  wire _unused = &{ena, uio_in, ui_in[7:4], 1'b0};

endmodule
