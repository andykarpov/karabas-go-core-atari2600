module spram (
	clock,
	address,
	data,
	wren,
	q,
	cs
);
	parameter addr_width = 8;
	parameter data_width = 8;
	parameter mem_init_file = " ";
	parameter sim_init_file = " ";
	parameter mem_name = "MEM";
	input wire clock;
	input wire [addr_width - 1:0] address;
	input wire [data_width - 1:0] data;
	input wire wren;
	output wire [data_width - 1:0] q;
	input wire cs;
	wire [data_width - 1:0] q_int;
	assign q = (cs ? q_int : {data_width {1'b1}});
	cache_ram #(
		.ADDR_WIDTH(addr_width),
		.DATA_WIDTH(data_width),
		.MEM_INIT_FILE(mem_init_file),
		.SIM_INIT_FILE(sim_init_file),
		.LPM_HINT({"ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=", mem_name})
	) u_ram(
		.clk_i(clock),
		.addr_i(address),
		.wren_i(wren & cs),
		.wdata_i(data),
		.q_o(q_int)
	);
endmodule
