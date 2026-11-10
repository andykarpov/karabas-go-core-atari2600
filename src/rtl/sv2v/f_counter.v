module f_counter (
	clk,
	reset,
	sys_reset,
	tick,
	clock,
	f1_qn,
	f1_qn_edge,
	f1_q_l
);
	input wire clk;
	input wire reset;
	input wire sys_reset;
	input wire tick;
	output wire [4:0] clock;
	output wire f1_qn;
	output wire f1_qn_edge;
	output wire f1_q_l;
	localparam EDGE_P1 = 3;
	localparam LEVEL_P1 = 0;
	localparam EDGE_P2 = 1;
	localparam LEVEL_P2 = 2;
	reg [1:0] f_count = 0;
	reg old_tick;
	reg old_reset;
	reg f1_qn_reg;
	wire tick_edge = ~old_tick && tick;
	assign clock[4] = tick_edge && ((f_count == EDGE_P1) || (reset && ~clock[2]));
	assign clock[3] = ((tick_edge && (f_count == EDGE_P2)) && ~clock[1]) && ~reset;
	assign clock[2] = (f_count == LEVEL_P1) || (reset && old_reset);
	assign clock[1] = f_count == LEVEL_P2;
	assign f1_qn_edge = tick_edge && (f_count == 3);
	assign f1_qn = (f_count == 0) || (f_count == 1);
	assign f1_q_l = (reset ? 1'd1 : (~f1_qn ? 1'd0 : f1_qn_reg));
	assign clock[0] = 0;
	always @(posedge clk) begin
		old_tick <= tick;
		old_reset <= reset;
		if (tick_edge)
			f_count <= f_count + 1'd1;
		if (reset || sys_reset) begin
			f_count <= (reset ? 1'd1 : 2'd0);
			if (sys_reset)
				old_tick <= 0;
			if (reset)
				f1_qn_reg <= 1;
		end
		if (~f1_qn)
			f1_qn_reg <= 0;
	end
endmodule
