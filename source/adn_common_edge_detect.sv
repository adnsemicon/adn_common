/*

### Purpose
This module provides a configurable edge detection mechanism for a single-bit input signal. It supports rising edge, falling edge, and dual-edge detection, generating a single-clock-cycle pulse whenever the specified transition occurs on the input signal relative to the system clock.

### Use Case
This module is primarily used in digital systems to synchronize asynchronous signals or to trigger state machine transitions based on specific signal changes. Common applications include:
- Generating a single-cycle trigger from a level-sensitive input (e.g., a button press or a status flag).
- Detecting the start of a data packet in serial communication protocols.
- Creating pulse-based control signals for counters or registers within a synchronous design.

Connect the system clock (`clk_i`), active-low reset (`arst_ni`), and the target signal (`signal_i`). The `edge_pulse_o` output will assert high for exactly one clock cycle when the specified transition is detected.

| REVISION | DATE       | AUTHOR                 | DESCRIPTION                                            |
|----------|------------|------------------------|--------------------------------------------------------|
| 0.1      | 2026-07-27 | Md. Sakib Hasan Shawon | Initial version                                        |
| 1.0      | 2026-07-28 | Md. Sakib Hasan Shawon | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed             | Ratified                                               |
| 1.2      | 2026-08-01 | Foez Ahmed             | Cycle fix                                              |
| 1.3      | 2026-08-01 | Foez Ahmed             | Ratified                                               |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_edge_detect #(
    // Edge detection mode: 0=Falling, 1=Rising, 2=Dual
    parameter int EDGE_TYPE = 0
) (
    // System clock input
    input  logic clk_i,
    // Active-low asynchronous reset
    input  logic arst_ni,
    // Input signal to be monitored for edges
    input  logic signal_i,
    // Output pulse indicating edge detection
    output logic edge_pulse_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Previous sampled value of the input signal used for edge comparison.
  logic signal_prev;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Main sequential block: Synchronous logic to detect transitions and update state.
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      // Reset state: Clear history and output pulse.
      signal_prev <= 1'b0;
    end else begin
      // Update stored input history for the next clock cycle.
      signal_prev <= signal_i;
    end
  end

  always_comb begin
    // Edge detection logic: Compare current input with previous state based on mode.
    case (EDGE_TYPE)
      // Falling edge detection:
      // Current signal is low and previous signal was high.
      0: edge_pulse_o <= signal_prev & ~signal_i;
      // Rising edge detection:
      // Current signal is high and previous signal was low.
      1: edge_pulse_o <= ~signal_prev & signal_i;
      // Both edge detection:
      // Current signal differs from previous sampled value.
      2: edge_pulse_o <= signal_prev ^ signal_i;
      // Invalid configuration handling.
      // Keep output deasserted for unsupported values.
      default: edge_pulse_o <= 1'b0;
    endcase
  end


`ifdef SIMULATION
  // Simulation-only block: Validate parameter configuration.
  initial begin
    assert (EDGE_TYPE >= 0 && EDGE_TYPE <= 2)
    else $fatal(1, "%m: EDGE_TYPE must be 0 (falling), 1 (rising), or 2 (both).");
  end
`endif

endmodule
