/*

### Purpose
This file provides a set of SystemVerilog macros designed to simplify the assignment and connection of PMI (Pipelined Memory Interface) signals between a master and a slave. It abstracts the repetitive task of mapping individual bus signals, reducing boilerplate code and minimizing the risk of connection errors.

### Use Case
This file is primarily used in testbenches or top-level integration modules where an PMI Master interface needs to be connected to an PMI Slave interface. By using these macros, developers can avoid manually writing out every signal assignment (psel, penable, paddr, etc.), which is prone to copy-paste errors. It supports different assignment types (combinational, blocking, and non-blocking) to accommodate various simulation and synthesis requirements.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 adnsemicon
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_PMI_ASSIGN_SVH__
`define __GUARD_PMI_ASSIGN_SVH__ 0


// Purpose: Connects PMI Master and Slave signals.
// Usecase: Used as a backend for specific assignment macros to map bus signals.
`define PMI_COMMUNICATION(__M__, __S__, __MT__, __AS__)                \
  ``__MT__`` ``__S__``.maddr  ``__AS__`` {'0, ``__M__``.maddr };       \
  ``__MT__`` ``__S__``.mwe    ``__AS__`` {'0, ``__M__``.mwe   };       \
  ``__MT__`` ``__S__``.mwdata ``__AS__`` {'0, ``__M__``.mwdata};       \
  ``__MT__`` ``__S__``.mstrb  ``__AS__`` {'0, ``__M__``.mstrb };       \
  ``__MT__`` ``__S__``.mreq   ``__AS__`` {'0, ``__M__``.mreq  };       \
  ``__MT__`` ``__S__``.mgnt   ``__AS__`` {'0, ``__M__``.mgnt  };       \
  ``__MT__`` ``__M__``.mack   ``__AS__`` {'0, ``__S__``.mack  };       \
  ``__MT__`` ``__M__``.mrdata ``__AS__`` {'0, ``__S__``.mrdata};       \
  ``__MT__`` ``__M__``.mresp  ``__AS__`` {'0, ``__S__``.mresp };       \


// Purpose: Performs a combinational assignment for PMI signals.
// Usecase: Typically used in continuous assignment contexts where the PMI signals need to reflect the current state of the master and slave interfaces without any delay.
`define PMI_COMB_ASSIGN(__M__, __S__)                                 \
  `PMI_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)            \


// Purpose: Performs a blocking assignment for PMI signals.
// Usecase: Typically used within procedural blocks (initial/always) for sequential logic or testbench stimulus where immediate signal updates are required.
`define PMI_BLOCKING_ASSIGN(__M__, __S__)                             \
  `PMI_COMMUNICATION(``__M__``, ``__S__``, , =)                       \


// Purpose: Performs a non-blocking assignment for PMI signals.
// Usecase: Typically used within procedural blocks (always_ff) for sequential logic where signal updates should occur at the end of the time step, allowing for proper simulation of clocked behavior.
`define PMI_NONBLOCKING_ASSIGN(__M__, __S__)                          \
  `PMI_COMMUNICATION(``__M__``, ``__S__``, , <=)                      \


`endif
