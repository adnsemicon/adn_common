/*

FILE: adn_common_synth_directives.svh

### Purpose
This file contains synthesis directives for not ungrouping and not optimizing the boundary the
modules. This file is intended to be included in synthesis scripts or synthesis-related files to
provide directives that control the synthesis behavior of ADN Common modules. The directives
specified in this file are used to ensure that the synthesis tool does not ungroup or optimize the
boundaries of the modules, which can be important for maintaining the intended structure and
functionality of the design.

### Use Case
This file must be included immediately before the module defination in the source code to ensure
that the synthesis directives are applied correctly. By including this file, designers can control
the synthesis behavior of ADN Common modules and ensure that the design is synthesized as intended,
without unwanted optimizations or ungrouping of module boundaries.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-07-20 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of https://github.com/adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

(* no_ungroup *)
(* no_boundary_optimization *)
