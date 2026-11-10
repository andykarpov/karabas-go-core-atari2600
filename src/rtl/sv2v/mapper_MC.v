module mapper_MC (
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
	load_start,
	rom_size
);
	parameter SLICE = 0;
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
	input load_start;
	input [31:0] rom_size;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? 8'hff : 8'h00);
	assign ram_sel = 1'd0;
	assign ram_a = 18'd0;
	assign ram_rw = 1'd1;
	reg [7:0] game;
	reg bank;
	reg reset_d;
	reg armed;
	wire [7:0] last_game = (SLICE == 0 ? rom_size[18:11] : (SLICE == 1 ? rom_size[19:12] : rom_size[20:13])) - 1'd1;
	always @(posedge clk) begin
		reset_d <= reset;
		if (load_start) begin
			game <= 0;
			armed <= 0;
		end
		else begin
			if (reset_d && !reset)
				armed <= 1;
			if ((reset && !reset_d) && armed)
				game <= (game + 1'd1) & last_game;
		end
		if (a_change)
			case (a_in)
				13'h1ff8: bank <= 0;
				13'h1ff9: bank <= 1;
				default:
					;
			endcase
		if (reset)
			bank <= 1;
	end
	generate
		if (SLICE == 0) begin : slice_2k
			assign rom_a = {game, a_in[10:0]};
		end
		else if (SLICE == 1) begin : slice_4k
			assign rom_a = {game[6:0], a_in[11:0]};
		end
		else begin : slice_8k
			assign rom_a = {game[5:0], bank, a_in[11:0]};
		end
	endgenerate
endmodule
