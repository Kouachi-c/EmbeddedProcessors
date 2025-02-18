
module nios_system (
	clk_clk,
	hex0_export,
	hex1_export,
	hex2_export,
	hex3_export,
	ledr_export,
	sw_export,
	reset_reset_n);	

	input		clk_clk;
	output	[7:0]	hex0_export;
	output	[7:0]	hex1_export;
	output	[7:0]	hex2_export;
	output	[7:0]	hex3_export;
	output	[9:0]	ledr_export;
	input	[9:0]	sw_export;
	input		reset_reset_n;
endmodule
