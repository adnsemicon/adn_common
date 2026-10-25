/*

### Purpose
The `adn_common_address_decoder` module is designed to perform address decoding by comparing an input address against a set of programmable address ranges. It identifies the corresponding slave device associated with the matched range and provides a priority-based selection mechanism to resolve overlapping address regions.

### Usage
To use this module, instantiate it by specifying the `ADDR_WIDTH`, `SLAVE_ID_WIDTH`, and `NUM_RULES`. Provide the input address via `addr_i` and define the address space mapping using the `min_addr_i`, `max_addr_i`, and `slave_id_i` arrays. The module will output the identified `slave_index_o` and a valid flag `addr_found_o` indicating if the address falls within any of the defined ranges.

| REVISION | DATE       | AUTHOR             | DESCRIPTION                                         |
|----------|------------|--------------------|-----------------------------------------------------|
| 1.0      | 2026-07-30 | Adnan Sami Anirban | Stable release                                      |
| 1.1      | 2026-09-14 | Foez Ahmed         | New ports (addr_o, addr_valid_o) added in FP ARB    |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_address_decoder #(

    parameter int ADDR_WIDTH     = 32,  // Width of the address bus
    parameter int SLAVE_ID_WIDTH = 4,   // Width of the slave identifier
    parameter int NUM_RULES      = 4    // Number of address ranges to decode

) (

    // Input address to be decoded
    input logic [    ADDR_WIDTH-1:0] addr_i,
    // Array of minimum address boundaries
    input logic [    ADDR_WIDTH-1:0] min_addr_i[NUM_RULES],
    // Array of maximum address boundaries
    input logic [    ADDR_WIDTH-1:0] max_addr_i[NUM_RULES],
    // Array of slave IDs corresponding to ranges
    input logic [SLAVE_ID_WIDTH-1:0] slave_id_i[NUM_RULES],

    // Identified slave ID
    output logic [SLAVE_ID_WIDTH-1:0] slave_index_o,
    // Valid flag if address matches a range
    output logic                      addr_found_o

);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // One-hot encoded vector indicating which address range the input address matches
  logic [NUM_RULES-1:0] match;
  // One-hot encoded grant vector from the fixed priority arbiter
  logic [NUM_RULES-1:0] gnt;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Generate block to instantiate multiple range comparators for each defined rule
  for (genvar i = 0; i < NUM_RULES; i++) begin : GEN_ADDRESS_COMPARE
    // Comparator submodule to check if addr_i is within [min_addr_i, max_addr_i]
    adn_common_range_checker #(
        .WIDTH(ADDR_WIDTH)
    ) u_address_range_compare (
        .min_i  (min_addr_i[i]),
        .max_i  (max_addr_i[i]),
        .value_i(addr_i),
        .match_o(match[i])
    );
  end

  adn_common_fixed_priority_arbiter #(
      .NUM_REQ            (NUM_RULES),
      .HIGH_INDEX_PRIORITY(1)
  ) u_fixed_priority_arbiter (
      .req_i       (match),
      .allow_req_i (1'b1),
      .gnt_o       (gnt),
      .addr_o      (),
      .addr_valid_o()
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // A match was found if the arbiter granted any request
  always_comb addr_found_o = |gnt;

  // Mux the slave_id_i array using the one-hot gnt vector to get the granted slave ID
  always_comb begin
    slave_index_o = '0;
    for (int i = 0; i < NUM_RULES; i = i + 1) begin
      if (gnt[i]) begin
        slave_index_o = slave_id_i[i];
      end
    end
  end

endmodule
