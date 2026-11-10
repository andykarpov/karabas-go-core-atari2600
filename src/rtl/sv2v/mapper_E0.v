module mapper_E0 (
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
	output wire [18:0] rom_a;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : 8'hff) : 8'h00);
	assign ram_sel = (sc ? a_in[12:8] == 5'b10000 : 1'd0);
	assign ram_a = (sc ? {11'd0, a_in[6:0]} : 18'd0);
	assign ram_rw = (sc ? a_in[7] : 1'd1);
	reg [8:0] banks;
	reg [2:0] current_bank;
	always @(posedge clk) begin
		if (a_change)
			case (a_in[12:3])
				10'h3fc: banks[6+:3] <= a_in[2:0];
				10'h3fd: banks[3+:3] <= a_in[2:0];
				10'h3fe: banks[0+:3] <= a_in[2:0];
				default:
					;
			endcase
		if (reset)
			banks <= 9'h000;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (a_in[11:10])
			0: current_bank = banks[6+:3];
			1: current_bank = banks[3+:3];
			2: current_bank = banks[0+:3];
			3: current_bank = 3'b111;
		endcase
	end
	assign rom_a = {3'd0, current_bank, a_in[9:0]};
	initial _sv2v_0 = 0;
endmodule
