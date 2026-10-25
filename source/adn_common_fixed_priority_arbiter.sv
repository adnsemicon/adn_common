/*

### Purpose
This module implements a fixed-priority arbiter that selects a single request from a multi-bit input vector based on a predefined priority scheme. It utilizes a priority encoder to determine the highest-priority active request and a decoder to generate a one-hot encoded grant signal, ensuring only one requester is granted access at any given time.

### Use-Case
This module is typically employed in bus interconnects, memory controllers, or any multi-master system where multiple agents compete for a shared resource. By enforcing a fixed-priority policy, it ensures that critical agents (e.g., high-bandwidth DMA engines or real-time processors) are serviced before lower-priority tasks, preventing resource contention and ensuring deterministic access latency.

| REVISION | DATE       | AUTHOR             | DESCRIPTION                                         |
|----------|------------|--------------------|-----------------------------------------------------|
| 0.1      | 2026-07-30 | Shykul Islam Siam  | Initial version                                     |
| 1.0      | 2026-07-30 | Shykul Islam Siam  | Stable release                                      |
| 1.1      | 2026-08-01 | Foez Ahmed         | Ports Fixed and simplified logic                    |
| 1.2      | 2026-08-01 | Foez Ahmed         | Ratified                                            |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_fixed_priority_arbiter #(
    parameter int NUM_REQ             = 4,  // Number of request lines; must be at least one.
    parameter bit HIGH_INDEX_PRIORITY = 0   // When set, the highest index request has priority.
) (
    input logic [NUM_REQ-1:0] req_i,       // Request vector, higher index has higher priority
    input logic               allow_req_i, // Global enable signal to permit granting

    output logic [NUM_REQ-1:0] gnt_o,  // One-hot encoded grant output

    output logic [$clog2(NUM_REQ)-1:0] addr_o,       // Encoded index of the granted request
    output logic                       addr_valid_o  // Indicates if a valid grant is present
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Priority encoder to determine the index of the highest priority request
  adn_common_priority_encoder #(
      .NUM_WIRE           (NUM_REQ),
      .HIGH_INDEX_PRIORITY(HIGH_INDEX_PRIORITY)
  ) u_encoder (
      .d_i         (req_i),
      .addr_o      (addr_o),
      .addr_valid_o(addr_valid_o)
  );

  // Decoder to convert the encoded index back to a one-hot grant signal
  adn_common_decoder #(
      .ADDR_WIDTH($clog2(NUM_REQ)),
      .DATA_WIDTH(NUM_REQ)
  ) u_decoder (
      .addr_i      (addr_o),
      .addr_valid_i(addr_valid_o & allow_req_i),
      .d_o         (gnt_o)
  );

endmodule
