module mapper_3E (
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
	input [18:0] rom_size;
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : 8'hff) : 8'h00);
	reg ram_en;
	assign ram_sel = (a_in[12] && ~a_in[11]) && ram_en;
	reg [4:0] ram_bank;
	assign ram_a = {ram_bank, a_in[9:0]};
	assign ram_rw = (~a_in[10] || ~ram_en) || a_change;
	reg [7:0] bank;
	wire [7:0] highest_bank = rom_size[18:11] - 1'd1;
	wire [7:0] current_bank = (~a_in[11] ? bank : highest_bank);
	always @(posedge clk) begin
		case (a_in)
			13'h003f: begin
				bank <= d_in[7:0];
				ram_en <= 0;
			end
			13'h003e: begin
				ram_en <= 1;
				ram_bank <= d_in[4:0];
			end
		endcase
		if (reset) begin
			bank <= 4'd0;
			ram_bank <= 4'd0;
			ram_en <= 0;
		end
	end
	assign rom_a = {current_bank, a_in[10:0]};
endmodule
