# SystemVerilog Coding and Commenting Guideline

This guideline is tailored to how [sv_documenter.py](sv_documenter.py) and [rtl_svg.py](rtl_svg.py) extract information and generate Markdown/SVG output.

## Goal

Write SystemVerilog so that:

1. Documentation is generated correctly.
2. Port/parameter descriptions are captured reliably.
3. Top-level IO SVGs are readable and accurate.

## File Header Standard

Use a top block comment at the beginning of each file.

```systemverilog
/*
 * Module: adn_common_example
 * Author: Your Name
 * Brief: One-line summary.
 * Details: Optional multi-line behavior notes.
 */
```

Rules:

1. Put `Author:` in the header if author capture is desired.
2. Keep meaningful functional text in the header.
3. Avoid only license boilerplate in the header, because boilerplate lines are filtered from the description.

## Module / Program / Interface Style (Parser-Friendly)

The documenter recognizes `module`, `program`, and `interface` declarations and parses ANSI-style parameters and ports.

### Declaration Pattern

Preferred pattern:

```systemverilog
module adn_common_example #(
	parameter int unsigned DEPTH = 16, // FIFO depth
	parameter int unsigned WIDTH = 32  // Data width
) (
	input  logic                 clk,      // Clock
	input  logic                 rst_n,    // Active-low reset
	input  logic [WIDTH-1:0]     data_i,   // Input data
	output logic [WIDTH-1:0]     data_o    // Output data
);
```

Rules:

1. Use ANSI-style declarations in the module header.
2. Keep one parameter per comma item.
3. Keep one signal per port item.
4. End parameter/port lists with balanced parentheses and commas only at top level.
5. Prefer placing unpacked dimensions with the name (`sig[3:0]`) so dimension extraction is deterministic.

### Port Direction Mapping for SVG

The SVG generator maps directions as:

1. `input` -> left side.
2. `output`, `inout`, `ref`, and interface-like entries -> right side.

Implications:

1. If you want a signal on the left side in top IO SVG, declare it as `input`.
2. Keep port names concise; very long names widen diagrams significantly.

## Commenting Rules for Auto-Descriptions

The documenter uses two strategies for symbol descriptions (`parameter`, `port`, macro names):

1. Inline `//` comment on the same line as the symbol.
2. Consecutive `//` comments immediately above the symbol.

Preferred style:

```systemverilog
// Number of entries in internal queue
parameter int unsigned DEPTH = 16;

input logic clk; // Primary module clock
```

Rules:

1. Prefer same-line `//` for short descriptions.
2. Use directly-adjacent preceding `//` lines for longer text.
3. Do not separate preceding comments from the symbol with unrelated code.

## Package Style

The parser extracts package info from:

1. `package <name>; ... endpackage`
2. `parameter` and `localparam` statements
3. `typedef struct packed { ... } <type_name>;`

Recommended pattern:

```systemverilog
package adn_common_pkg;

	// Maximum transaction size in bytes
	parameter int unsigned MAX_BYTES = 64;

	typedef struct packed {
		logic [7:0] opcode;
		logic [3:0] id;
	} txn_t;

endpackage
```

Rules:

1. Use explicit `package ... endpackage`.
2. Keep parameter statements well-formed and semicolon-terminated.
3. Prefer `typedef struct packed` when you want typedef names listed automatically.

## Include File and Macro Style (`.svh` / `.vh`)

Include files are parsed for include guards and macros.

**Recommended guard pattern:** start with `__GUARD_`, followed by the file path relative to the include directory in uppercase snake_case, ending with `__`. `/` and `.` are replaced with `_`. For example, `include/vip/example.svh` becomes `__GUARD_VIP_EXAMPLE_SVH__`.

```systemverilog
`ifndef __GUARD_VIP_EXAMPLE_SVH__
`define __GUARD_VIP_EXAMPLE_SVH__ 0

// Returns min of two values
`define ADN_MIN(a, b) (((a) < (b)) ? (a) : (b))

`endif
```

Rules:

1. Keep `ifndef` and `define` guard tokens identical.
2. Document each functional macro with either:
   1. same-line `//` comment, or
   2. directly preceding `//` or `/* ... */` comment block.
3. Multi-line macros must use trailing `\` continuation.
4. The include guard helper macro is intentionally omitted from macro tables; document functional macros separately.

## Naming and Layout Recommendations

These are style recommendations to improve readability and diagram quality.

1. Use lowercase snake_case for signals and ports.
2. Use uppercase snake_case for macros and include-guard tokens.
3. Use clear suffixes such as `_i`, `_o`, `_io` for direction clarity.
4. Keep declaration formatting aligned in columns where possible.
5. Keep comments concise and behavior-focused.

## Anti-Patterns to Avoid

1. Multiple unrelated declarations on one line with one trailing comment.
2. Non-ANSI module declarations when expecting full auto-documentation.
3. Port bundles declared in one item (`input logic a, b, c`) when each needs distinct description metadata.
4. Missing package/include terminators.
5. Unbalanced parentheses/brackets in parameter defaults or macro arguments.

## Minimal Templates

### Module Template

```systemverilog
/*
 * Author: Your Name
 * Brief: What this module does.
 */
module example_mod #(
	parameter int unsigned WIDTH = 8 // Data bus width
) (
	input  logic             clk,    // Clock
	input  logic             rst_n,  // Active-low reset
	input  logic [WIDTH-1:0] data_i, // Input payload
	output logic [WIDTH-1:0] data_o  // Output payload
);

endmodule
```

### Include Template

```systemverilog
`ifndef EXAMPLE_SVH
`define EXAMPLE_SVH

// Returns absolute value
`define ABS_VAL(x) (((x) < 0) ? -(x) : (x))

`endif
```

## Quick Validation Command

From [submodule/documenter](.), run:

```bash
python sv_documenter.py ../../source -o ../../document/source
python sv_documenter.py ../../include -o ../../document/include
```

If no files are found, verify extensions are one of: `.sv`, `.svh`, `.vh`, `.v`.
