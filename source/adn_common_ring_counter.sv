/*

The `adn_common_ring_counter` module implements a synchronous one-hot ring counter. It rotates a single high bit through a register of a configurable width, providing a circular shift operation that is useful for state machine sequencing, token passing, or simple pulse generation.

### Use Cases
- **Round-Robin Arbitration**: Distributing access to a shared resource among multiple requesters.
- **Time-Division Multiplexing (TDM)**: Generating control signals to enable different data paths in a sequential manner.
- **Pulse Train Generation**: Creating periodic pulses for triggering events at specific clock cycles.
- **State Machine Sequencing**: Implementing simple, low-overhead state machines where each state is represented by a single bit.

- **`clk_i`**: Connect to the system clock.
- **`arst_ni`**: Connect to an active-low asynchronous or synchronous reset. Upon reset, the counter initializes to `100...0`.
- **`enable_i`**: When high, the counter shifts the high bit to the next position on the rising edge of the clock.
- **`data_o`**: The one-hot encoded output vector.

| REVISION | DATE       | AUTHOR                 | DESCRIPTION                                     |
|----------|------------|------------------------|-------------------------------------------------|
| 0.1      | 2026-07-30 | Md. Sakib Hasan Shawon | Initial version                                 |
| 1.0      | 2026-07-30 | Md. Sakib Hasan Shawon | Stable release                                  |
| 1.1      | 2026-08-01 | Foez Ahmed             | Ratified                                        |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_ring_counter #(
    // DATA_WIDTH defines the number of bits in the ring counter
    parameter int DATA_WIDTH = 4
) (
    // System clock signal
    input logic clk_i,

    // Active-low asynchronous reset signal
    input logic arst_ni,

    // Enable signal to trigger the rotation of the bit
    input logic enable_i,

    // One-hot encoded vector representing the current state
    output logic [DATA_WIDTH-1:0] data_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Localparam: RESET_VALUE defines the initial state (100...0) loaded during reset
  localparam logic [DATA_WIDTH-1:0] RESET_VALUE = {1'b1, {(DATA_WIDTH - 1) {1'b0}}};

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Signal: ring_counter holds the internal state of the one-hot register
  logic [DATA_WIDTH-1:0] ring_counter;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Assignment: Connect the internal register to the module output port
  assign data_o = ring_counter;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Block: Sequential logic to update the ring counter state on clock edges
  always_ff @(posedge clk_i or negedge arst_ni) begin

    if (~arst_ni) begin

      // Reset logic: Initialize the counter to the defined RESET_VALUE
      ring_counter <= RESET_VALUE;

    end else if (enable_i) begin

      // Rotation logic: Perform a circular left shift of the one-hot bit
      ring_counter <= {ring_counter[DATA_WIDTH-2:0], ring_counter[DATA_WIDTH-1]};

    end

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION

  // Block: Simulation-only check to ensure valid parameter configuration
  initial begin

    if (DATA_WIDTH < 2) begin
      $error("DATA_WIDTH must be greater than 1");
    end

  end

`endif

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION

  // Assertion: Verify that the output remains one-hot at every clock cycle
  assert property (@(posedge clk_i) $onehot(data_o))
  else $error("Ring counter entered invalid state");

`endif

endmodule
