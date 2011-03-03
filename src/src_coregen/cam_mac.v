/*******************************************************************************
*     This file is owned and controlled by Xilinx and must be used             *
*     solely for design, simulation, implementation and creation of            *
*     design files limited to Xilinx devices or technologies. Use              *
*     with non-Xilinx devices or technologies is expressly prohibited          *
*     and immediately terminates your license.                                 *
*                                                                              *
*     XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"            *
*     SOLELY FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR                  *
*     XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION          *
*     AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION              *
*     OR STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS                *
*     IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,                  *
*     AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE         *
*     FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY                 *
*     WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE                  *
*     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR           *
*     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF          *
*     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          *
*     FOR A PARTICULAR PURPOSE.                                                *
*                                                                              *
*     Xilinx products are not intended for use in life support                 *
*     appliances, devices, or systems. Use in such applications are            *
*     expressly prohibited.                                                    *
*                                                                              *
*     (c) Copyright 1995-2007 Xilinx, Inc.                                     *
*     All rights reserved.                                                     *
*******************************************************************************/
// The synthesis directives "translate_off/translate_on" specified below are
// supported by Xilinx, Mentor Graphics and Synplicity synthesis
// tools. Ensure they are correct for your synthesis tool(s).

// You must compile the wrapper file cam_mac.v when simulating
// the core, cam_mac. When compiling the wrapper file, be sure to
// reference the XilinxCoreLib Verilog simulation library. For detailed
// instructions, please refer to the "CORE Generator Help".

`timescale 1ns/1ps

module cam_mac(
	clk,
	cmp_din,
	din,
	en,
	we,
	wr_addr,
	busy,
	match,
	match_addr);


input clk;
input [47 : 0] cmp_din;
input [47 : 0] din;
input en;
input we;
input [3 : 0] wr_addr;
output busy;
output match;
output [3 : 0] match_addr;

// synthesis translate_off

      CAM_V6_1 #(
		.c_addr_type(0),
		.c_cmp_data_mask_width(48),
		.c_cmp_din_width(48),
		.c_data_mask_width(48),
		.c_depth(16),
		.c_din_width(48),
		.c_has_cmp_data_mask(0),
		.c_has_cmp_din(1),
		.c_has_data_mask(0),
		.c_has_en(1),
		.c_has_multiple_match(0),
		.c_has_read_warning(0),
		.c_has_single_match(0),
		.c_has_we(1),
		.c_has_wr_addr(1),
		.c_match_addr_width(4),
		.c_match_resolution_type(0),
		.c_mem_init(0),
		.c_mem_init_file("no_coe_file_loaded"),
		.c_mem_type(0),
		.c_read_cycles(1),
		.c_reg_outputs(0),
		.c_ternary_mode(0),
		.c_width(48),
		.c_wr_addr_width(4))
	inst (
		.CLK(clk),
		.CMP_DIN(cmp_din),
		.DIN(din),
		.EN(en),
		.WE(we),
		.WR_ADDR(wr_addr),
		.BUSY(busy),
		.MATCH(match),
		.MATCH_ADDR(match_addr),
		.CMP_DATA_MASK(),
		.DATA_MASK(),
		.MULTIPLE_MATCH(),
		.READ_WARNING(),
		.SINGLE_MATCH());


// synthesis translate_on

endmodule

