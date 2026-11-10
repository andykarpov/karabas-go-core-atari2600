module mapper_0840 (
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
	rom_a
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
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? 8'hff : 8'h00);
	assign ram_sel = 1'd0;
	assign ram_a = 18'd0;
	assign ram_rw = 1'd1;
	reg bank;
	always @(posedge clk) begin
		if (a_change && (a_in[12:11] == 2'b01))
			bank <= a_in[6];
		if (reset)
			bank <= 0;
	end
	assign rom_a = {6'd0, bank, a_in[11:0]};
endmodule
