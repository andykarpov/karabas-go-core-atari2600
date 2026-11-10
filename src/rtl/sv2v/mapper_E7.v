module mapper_E7 (
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
	reg _sv2v_0;
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
	output reg [18:0] rom_a;
	reg [2:0] bank;
	reg [1:0] ram_bank;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : 8'hff) : 8'h00);
	assign ram_sel = ((a_in[12:11] == 2'b10) && &bank) || (a_in[12:9] == 4'b1100);
	assign ram_a = (a_in[12:11] == 2'b10 ? {8'd0, a_in[9:0]} : {8'h01, ram_bank, a_in[7:0]});
	assign ram_rw = (a_in[12:11] == 2'b10 ? a_in[10] || ~&bank : a_in[8]);
	always @(*) begin
		if (_sv2v_0)
			;
		rom_a = {4'b0000, a_in[11:0]};
		if (a_in[12:11] == 2'b10)
			rom_a = {1'b0, bank, a_in[10:0]};
		else if ((a_in[12:11] == 2'b11) || (a_in[12:10] == 3'b101))
			rom_a = {5'b01111, a_in[10:0]};
	end
	always @(posedge clk) begin
		if (a_change) begin
			if (a_in[12:4] == 9'h1fe) begin
				if (~a_in[3])
					bank <= a_in[2:0];
				else if (~a_in[2])
					ram_bank <= a_in[1:0];
			end
		end
		if (reset) begin
			bank <= 0;
			ram_bank <= 0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
