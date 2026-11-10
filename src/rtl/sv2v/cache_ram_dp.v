module cache_ram_dp (
	clk_i,
	addr_a_i,
	wren_a_i,
	wdata_a_i,
	q_a_o,
	addr_b_i,
	wren_b_i,
	wdata_b_i,
	q_b_o
);
	parameter ADDR_WIDTH = 7;
	parameter DATA_WIDTH = 32;
	parameter MEM_INIT_FILE = " ";
	parameter DEVICE_FAMILY = "Cyclone V";
	parameter SIM_INIT_FILE = " ";
	input wire clk_i;
	input wire [ADDR_WIDTH - 1:0] addr_a_i;
	input wire wren_a_i;
	input wire [DATA_WIDTH - 1:0] wdata_a_i;
	output wire [DATA_WIDTH - 1:0] q_a_o;
	input wire [ADDR_WIDTH - 1:0] addr_b_i;
	input wire wren_b_i;
	input wire [DATA_WIDTH - 1:0] wdata_b_i;
	output wire [DATA_WIDTH - 1:0] q_b_o;
	localparam NUM_WORDS = 1 << ADDR_WIDTH;
	reg [DATA_WIDTH - 1:0] q_a_out;
	reg [DATA_WIDTH - 1:0] q_b_out;
	(* ramstyle = "M10K, no_rw_check" *) reg [DATA_WIDTH - 1:0] mem_q [0:NUM_WORDS - 1];
	integer init_i;
	initial if (SIM_INIT_FILE != " ")
		$readmemh(SIM_INIT_FILE, mem_q);
	else
		for (init_i = 0; init_i < NUM_WORDS; init_i = init_i + 1)
			mem_q[init_i] = {DATA_WIDTH {1'b0}};
	always @(posedge clk_i) begin
		if (wren_a_i)
			mem_q[addr_a_i] <= wdata_a_i;
		if (wren_a_i)
			q_a_out <= wdata_a_i;
		else
			q_a_out <= mem_q[addr_a_i];
		if (wren_b_i)
			mem_q[addr_b_i] <= wdata_b_i;
		if (wren_b_i)
			q_b_out <= wdata_b_i;
		else
			q_b_out <= mem_q[addr_b_i];
	end
	assign q_a_o = q_a_out;
	assign q_b_o = q_b_out;
endmodule
