module cache_ram (
	clk_i,
	addr_i,
	wren_i,
	wdata_i,
	q_o
);
	parameter ADDR_WIDTH = 7;
	parameter DATA_WIDTH = 32;
	parameter MEM_INIT_FILE = " ";
	parameter SIM_INIT_FILE = " ";
	parameter DEVICE_FAMILY = "Cyclone V";
	parameter LPM_HINT = "ENABLE_RUNTIME_MOD=NO";
	input wire clk_i;
	input wire [ADDR_WIDTH - 1:0] addr_i;
	input wire wren_i;
	input wire [DATA_WIDTH - 1:0] wdata_i;
	output wire [DATA_WIDTH - 1:0] q_o;
	localparam NUM_WORDS = 1 << ADDR_WIDTH;
	reg [DATA_WIDTH - 1:0] q_out;
	(* ramstyle = "M10K, no_rw_check" *) reg [DATA_WIDTH - 1:0] mem_q [0:NUM_WORDS - 1];
	integer init_i;
	initial if (SIM_INIT_FILE != " ")
		$readmemh(SIM_INIT_FILE, mem_q);
	else
		for (init_i = 0; init_i < NUM_WORDS; init_i = init_i + 1)
			mem_q[init_i] = {DATA_WIDTH {1'b0}};
	always @(posedge clk_i) begin
		if (wren_i)
			mem_q[addr_i] <= wdata_i;
		if (wren_i)
			q_out <= wdata_i;
		else
			q_out <= mem_q[addr_i];
	end
	assign q_o = q_out;
endmodule
