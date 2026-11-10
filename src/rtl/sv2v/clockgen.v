module clockgen (
	clk,
	is_7800,
	ce,
	reset,
	rsync,
	rsynd,
	pext_1,
	pext_2,
	rsynl,
	pclk,
	hclk,
	oclk,
	phi0_ll,
	pclk_gen_edge_p1,
	pclk_gen_edge_p2
);
	input wire clk;
	input wire is_7800;
	input wire ce;
	input wire reset;
	input wire rsync;
	input wire rsynd;
	input wire pext_1;
	input wire pext_2;
	output wire rsynl;
	output wire [4:0] pclk;
	output wire [4:0] hclk;
	output wire [4:0] oclk;
	output wire phi0_ll;
	output wire pclk_gen_edge_p1;
	output wire pclk_gen_edge_p2;
	parameter PHI2_EXT = 0;
	reg oclk_tog;
	reg [2:0] pclk_div;
	wire pclock;
	reg oclk_clock;
	reg pclk_clock;
	wire pclk_edge = oclk[4] || oclk[3];
	assign oclk[3] = oclk_tog && ce;
	assign oclk[4] = ~oclk_tog && ce;
	assign oclk[0] = oclk_clock;
	assign oclk[2] = ~oclk_clock;
	assign oclk[1] = oclk_clock;
	assign pclk_gen_edge_p2 = ((pclk_div == 2) && pclk_edge) && ~pclk_clock;
	wire resp0 = (hclk[1] && rsynd) || reset;
	assign pclk_gen_edge_p1 = (((pclk_div == 5) || (resp0 && (pclk_div == 0))) && pclk_edge) && pclk_clock;
	assign pclk[3] = (is_7800 || PHI2_EXT ? pext_2 && ~pclk_clock : pclk_gen_edge_p2);
	assign pclk[4] = (is_7800 ? pext_1 && pclk_clock : pclk_gen_edge_p1);
	assign pclk[0] = pclk_clock;
	assign pclk[2] = ~pclk_clock;
	assign pclk[1] = pclk_clock;
	wire [4:0] hclk_ll;
	wire [4:0] hclk_hl;
	f_counter hclk_counter(
		.clk(clk),
		.reset(rsync),
		.sys_reset(reset),
		.tick(oclk[3]),
		.clock(hclk),
		.f1_qn(),
		.f1_qn_edge(),
		.f1_q_l(rsynl)
	);
	assign phi0_ll = 0;
	always @(posedge clk) begin : phi0_gen
		if (ce)
			oclk_tog <= ~oclk_tog;
		if (oclk[3])
			oclk_clock <= 1;
		else if (oclk[4])
			oclk_clock <= 0;
		if (pclk_edge)
			pclk_div <= (pclk_div == 5 ? 3'd0 : pclk_div + 1'd1);
		if (pclk[3])
			pclk_clock <= 1'b1;
		else if (pclk[4])
			pclk_clock <= 1'b0;
		if (hclk[3] && rsynd)
			pclk_div <= 3'd2;
		if (reset) begin
			pclk_div <= 3'd4;
			oclk_tog <= 0;
			oclk_clock <= 1'sb0;
			pclk_clock <= 0;
		end
	end
endmodule
