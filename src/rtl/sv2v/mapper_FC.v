module mapper_FC (
	clk,
	reset,
	a_change,
	sc,
	a_in,
	d_in,
	d_out,
	flags_out,
	oe,
	ram_sel,
	ram_rw,
	ram_a,
	rom_a,
	rom_size
);
	input clk;
	input reset;
	input a_change;
	input sc;
	input [12:0] a_in;
	input [7:0] d_in;
	output wire [7:0] d_out;
	output wire [15:0] flags_out;
	output wire [7:0] oe;
	output wire ram_sel;
	output wire ram_rw;
	output wire [17:0] ram_a;
	output wire [18:0] rom_a;
	input [31:0] rom_size;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? 8'hff : 8'h00);
	assign ram_sel = 1'd0;
	assign ram_a = 18'd0;
	assign ram_rw = 1'd1;
	reg [2:0] bank;
	reg [1:0] lo;
	reg [7:0] hi;
	wire [2:0] last_bank = rom_size[14:12] - 1'd1;
	wire hi_fits = {hi[5:0], 2'b00} <= {5'd0, last_bank};
	wire [2:0] target = (hi_fits ? {hi[0], lo} : hi[2:0]) & last_bank;
	always @(posedge clk) begin
		if (a_in == 13'h1ff8)
			lo <= d_in[1:0];
		if (a_in == 13'h1ff9)
			hi <= d_in;
		if (a_change && (a_in == 13'h1ffc))
			bank <= target;
		if (reset) begin
			bank <= 0;
			lo <= 0;
			hi <= 0;
		end
	end
	assign rom_a = {4'd0, bank, a_in[11:0]};
endmodule
