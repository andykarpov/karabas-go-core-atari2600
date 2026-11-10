module mapper_32 (
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
	cold_reset
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
	input cold_reset;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : 8'hff) : 8'h00);
	assign ram_sel = (sc ? a_in[12:8] == 5'b10000 : 1'd0);
	assign ram_a = (sc ? {11'd0, a_in[6:0]} : 18'd0);
	assign ram_rw = (sc ? a_in[7] : 1'd1);
	reg [4:0] bank;
	reg old_reset;
	always @(posedge clk) begin
		old_reset <= reset;
		if (~old_reset && reset)
			bank <= bank + 1'd1;
		if (cold_reset)
			bank <= 0;
	end
	assign rom_a = {bank, a_in[10:0]};
endmodule
