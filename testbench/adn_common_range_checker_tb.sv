/*

| TEST CASE | DATE       | AUTHOR            | DESCRIPTION                             |
|-----------|------------|-------------------|-----------------------------------------|
| TC_001    | 2026-08-18 | Shykul Islam Siam | Inclusive lower-bound behavior          |
| TC_002    | 2026-08-18 | Shykul Islam Siam | Exclusive upper-bound behavior          |
| TC_003    | 2026-08-18 | Shykul Islam Siam | Values outside a valid range            |
| TC_004    | 2026-08-18 | Shykul Islam Siam | Values within a valid range             |
| TC_005    | 2026-08-18 | Shykul Islam Siam | Equal and reversed invalid ranges       |
| TC_006    | 2026-08-18 | Shykul Islam Siam | Representable-value boundary conditions |
| TC_007    | 2026-08-18 | Shykul Islam Siam | Randomized reference-model regression   |
| TC_ALL    | 2026-08-18 | Shykul Islam Siam | All directed and randomized tests       |

| REVISION | DATE       | AUTHOR            | DESCRIPTION                       |
|----------|------------|-------------------|-----------------------------------|
| 0.1      | 2026-08-18 | Shykul Islam Siam | Initial version                   |
| 1.0      | 2026-08-18 | Shykul Islam Siam | Stable release                    |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_range_checker_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Pulls in the shared testbench infrastructure (test_name, test_count, debug,
  // note_case(), and other common plusarg-driven helpers used by all ADN testbenches).

  `include "vip/adn_common_tb_headers.sv"  // shared TB utilities / plusarg parsing

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Bit width used to size all DUT ports and testbench signals below.

  localparam int WIDTH = 8;  // data width in bits for min/max/value signals

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Testbench-side signals that drive/observe the DUT ports.

  logic [WIDTH-1:0] min_i;    // inclusive lower bound driven into the DUT
  logic [WIDTH-1:0] max_i;    // exclusive upper bound driven into the DUT
  logic [WIDTH-1:0] value_i;  // value under test driven into the DUT
  logic             match_o;  // DUT output: 1 if value_i falls within [min_i, max_i)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Instantiation of the design under test (DUT).

  adn_common_range_checker #(
      .WIDTH(WIDTH)  // propagate testbench WIDTH into the DUT parameter
  ) dut (
      .min_i  (min_i),    // -> DUT inclusive minimum
      .max_i  (max_i),    // -> DUT exclusive maximum
      .value_i(value_i),  // -> DUT value to check
      .match_o(match_o)   // <- DUT range-match result
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Reference model and reusable stimulus/checking tasks shared by every test case.

  // Golden/reference model: mirrors the DUT's expected [min, max) semantics.
  // Returns 1 only when min < max AND value is in the half-open interval.
  function automatic logic expected_match(input logic [WIDTH-1:0] min_value,
                                          input logic [WIDTH-1:0] max_value,
                                          input logic [WIDTH-1:0] value);
    return (min_value < max_value) && (value >= min_value) && (value < max_value);  // inclusive-low, exclusive-high check
  endfunction

  // Drives one stimulus vector into the DUT, compares against the reference
  // model, logs a pass/fail, and records the result via note_case().
  task automatic check_range(input logic [WIDTH-1:0] min_value,
                             input logic [WIDTH-1:0] max_value,
                             input logic [WIDTH-1:0] value,
                             input string label);
    logic expected;  // reference-model expected result
    bit   pass;      // actual-vs-expected comparison result

    // Drive DUT inputs for this vector
    min_i   = min_value;
    max_i   = max_value;
    value_i = value;
    #1;  // allow combinational logic to settle

    // Compare DUT output against the reference model
    expected = expected_match(min_value, max_value, value);
    pass     = (match_o === expected);
    note_case(pass);  // tally this check into the overall pass/fail count

    // Only print on failure, unless debug mode is enabled
    if (debug || !pass) begin
      $display("[%s][%s] %s: min=0x%0h max=0x%0h value=0x%0h expected=%0b actual=%0b", pass ? "PASS" : "FAIL", test_name, label, min_value, max_value, value, expected, match_o);
    end
  endtask

  // Runs a batch of randomized min/max/value combinations through
  // check_range() to stress the DUT against the reference model.
  task automatic run_random_tests(input int count);
    logic [WIDTH-1:0] random_min;    // randomized lower bound
    logic [WIDTH-1:0] random_max;    // randomized upper bound
    logic [WIDTH-1:0] random_value;  // randomized value under test

    repeat (count) begin
      random_min   = $urandom;  // draw random min
      random_max   = $urandom;  // draw random max
      random_value = $urandom;  // draw random value
      check_range(random_min, random_max, random_value, "random reference-model check");  // check against golden model
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Main test sequencer: selects and runs the requested test case (via the
  // +test_name plusarg supplied by the common TB header) and finishes the sim.

  initial begin : main
    int random_count;  // number of randomized iterations to run for TC_007 / TC_ALL

    // Let the common header parse command-line plusargs before use.
    #0;  // yield one delta cycle so plusarg parsing in the header completes first
    random_count = (test_count > 0) ? test_count : 100;  // default to 100 random iterations if unset

    // Dispatch to the requested test case based on the +test_name plusarg.
    case (test_name)

      // TC_001: value sitting exactly on the inclusive lower bound must match.
      "TC_001": check_range(8'h20, 8'h40, 8'h20, "value equals inclusive minimum");

      // TC_002: exercise the exclusive-upper-bound behavior.
      "TC_002": begin
        check_range(8'h20, 8'h40, 8'h3f, "value immediately below maximum");  // last value that should match
        check_range(8'h20, 8'h40, 8'h40, "value equals exclusive maximum");   // boundary itself should NOT match
      end

      // TC_003: values that fall outside the valid range should never match.
      "TC_003": begin
        check_range(8'h20, 8'h40, 8'h1f, "value immediately below minimum");  // just under the lower bound
        check_range(8'h20, 8'h40, 8'h80, "value above maximum");              // well past the upper bound
      end

      // TC_004: values comfortably inside the valid range should match.
      "TC_004": begin
        check_range(8'h20, 8'h40, 8'h21, "value immediately above minimum");  // just above lower bound
        check_range(8'h20, 8'h40, 8'h30, "value in range midpoint");          // interior value
      end

      // TC_005: degenerate/invalid range configurations should never match.
      "TC_005": begin
        check_range(8'h20, 8'h20, 8'h20, "empty range rejects its boundary");  // min == max => empty range
        check_range(8'h40, 8'h20, 8'h30, "reversed range rejects middle value");  // min > max => invalid range
      end

      // TC_006: exercise the extremes of the representable value space.
      "TC_006": begin
        check_range(8'h00, 8'h01, 8'h00, "lowest representable value in range");     // smallest possible range
        check_range(8'h00, 8'hff, 8'hfe, "largest value below maximum in range");    // near full-width max
        check_range(8'h00, 8'hff, 8'hff, "maximum remains exclusive");               // full-width upper bound excluded
      end

      // TC_007: randomized regression against the reference model.
      "TC_007": run_random_tests(random_count);

      // TC_ALL / default (when no specific test_name is given): run every
      // directed check above plus the randomized regression, back to back.
      "TC_ALL", "default": begin
        check_range(8'h20, 8'h40, 8'h20, "value equals inclusive minimum");
        check_range(8'h20, 8'h40, 8'h3f, "value immediately below maximum");
        check_range(8'h20, 8'h40, 8'h40, "value equals exclusive maximum");
        check_range(8'h20, 8'h40, 8'h1f, "value immediately below minimum");
        check_range(8'h20, 8'h40, 8'h80, "value above maximum");
        check_range(8'h20, 8'h40, 8'h30, "value in range midpoint");
        check_range(8'h20, 8'h20, 8'h20, "empty range rejects its boundary");
        check_range(8'h40, 8'h20, 8'h30, "reversed range rejects middle value");
        check_range(8'h00, 8'h01, 8'h00, "lowest representable value in range");
        check_range(8'h00, 8'hff, 8'hfe, "largest value below maximum in range");
        check_range(8'h00, 8'hff, 8'hff, "maximum remains exclusive");
        run_random_tests(random_count);  // append randomized coverage after directed tests
      end

      // Unknown/unsupported +test_name value: fail loudly instead of silently
      // matching the default case above (guards against typos in test_name).
      default: begin
        $display("[FAIL] Unknown test case '%s'", test_name);
        note_case(1'b0);  // record as a failing test
      end
    endcase

    $finish;  // end simulation once the selected test case has completed
  end

endmodule