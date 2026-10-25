# pmi/typedef.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: typedef.svh

## Parameters

_None_


## Include Guard

__GUARD_PMI_TYPEDEF_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|PMI_REQ_T|__NM__, __AW__, __DW__|Macro: PMI_REQ_T Purpose: Generates a packed struct for an PMI request interface. Usecase: Use this to define the master-to-slave request signals with configurable address and data widths.|`define PMI_REQ_T(__NM__, __AW__, __DW__)         typedef struct packed {                         logic [``__AW__``-1:0]   maddr;               logic|
|PMI_RSP_T|__NM__, __DW__|Macro: PMI_RSP_T Purpose: Generates a packed struct for an PMI response interface. Usecase: Use this to define the slave-to-master response signals with configurable data width.|`define PMI_RSP_T(__NM__, __DW__)                 typedef struct packed {                         logic                    mgnt;                logic|
|PMI_T|__NM__, __AW__, __DW__|Macro: PMI_T Purpose: Generates both request and response packed structs for an PMI interface. Usecase: Use this to instantiate a complete PMI interface pair (req/rsp) with a single macro call, ensuring consistency across the design.|`define PMI_T(__NM__, __AW__, __DW__)             `PMI_REQ_T(``__NM__``, ``__AW__``, ``__DW__``)  `PMI_RSP_T(``__NM__``, ``__DW__``)|


## Description

# pmi/typedef.svh 
This file provides a collection of SystemVerilog macros designed to standardize the generation of packed structures for the PMI (Pipelined Memory Interface). By using these macros, developers can consistently define request and response interfaces with configurable address and data widths, ensuring architectural uniformity across the adnsemicon/adn_common project.

# pmi/typedef.svh  Case
This file serves as a centralized library for generating standardized SystemVerilog packed structures. It is primarily used to:
- Ensure architectural consistency across the PMI (Pipelined Memory Interface) by enforcing a uniform signal layout.
- Reduce boilerplate code when defining request and response interfaces.
- Provide flexibility through configurable parameters for address (`__AW__`) and data (`__DW__`) widths.
- Facilitate rapid integration of master-slave communication channels in the `adnsemicon/adn_common` project.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-04 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
