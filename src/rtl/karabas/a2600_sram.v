`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_sram.v

 The cartridge of atari2600_top in the SRAM of the board (two 2M x 8 chips = one 2M x 16, 10 ns,
 asynchronous; MD[7:0] / MWR_N[0] / MRD_N[0] the low byte), on clk_sys (32.5 MHz, 30.8 ns a clock).
 Byte addresses: the ROM image at 0 (rom_a, up to 512 KB), the cartridge RAM at 1 MB (cartram_addr,
 up to 256 KB); the loader (FL item, default cartridge of the .kg) writes the image at 0.

 Reads: every idle clock the address of the machine (cartram_addr while cartram_rd / cartram_wr,
 else rom_a) goes out of an IOB flip-flop with both /OE low, MD comes into an IOB flip-flop on the
 next edge and the byte of its lane is taken one edge later into rom_do or cartram_data (by the
 region it was read for): three clocks (92 ns) from an address to its byte, against a 6507 cycle
 of 838 ns. The other output keeps its last byte.
 Writes take three clocks (as archie_sram): MA and MD out with /OE off, /WE of the lane low, /WE
 high (address and data held a clock around /WE). A load byte waits in a register (the loader
 gives one in 9 clocks or more); a cartridge RAM write is done again and again while cartram_wr is
 high (the last one keeps the final data, as the block RAM of k7800 that writes every clock).
*/
module a2600_sram (
	input wire clk,

	input wire ld_wr,              // one clock per byte
	input wire [18:0] ld_addr,
	input wire [7:0] ld_data,

	input wire [18:0] rom_a,
	output reg [7:0] rom_do = 8'hFF,
	input wire [17:0] cartram_addr,
	input wire cartram_rd,
	input wire cartram_wr,
	input wire [7:0] cartram_wrdata,
	output reg [7:0] cartram_data = 8'hFF,

	output wire [20:0] MA,
	input wire [15:0] MD_I,        // the pins MD: the top makes the tristate (MD = md_oe_n ? z : MD_O)
	output wire [15:0] MD_O,
	output wire [15:0] MD_OE_N,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N
);

(* IOB = "TRUE" *) reg [20:0] ma_r = 21'd0;
(* IOB = "TRUE" *) reg [1:0] mwr_r = 2'b11;
(* IOB = "TRUE" *) reg [1:0] mrd_r = 2'b11;
(* IOB = "TRUE" *) reg [15:0] md_out = 16'd0;
(* IOB = "TRUE", equivalent_register_removal = "no" *) reg [15:0] md_oe_n = 16'hFFFF;
(* IOB = "TRUE" *) reg [15:0] md_in = 16'd0;

assign MA = ma_r;
assign MWR_N = mwr_r;
assign MRD_N = mrd_r;
assign MD_O = md_out;
assign MD_OE_N = md_oe_n;

// a load byte waiting for its write
reg ld_pend = 1'b0;
reg [18:0] ld_a = 19'd0;
reg [7:0] ld_d = 8'd0;

localparam S_IDLE = 2'd0, S_SETUP = 2'd1, S_WE = 2'd2, S_HOLD = 2'd3;
reg [1:0] st = S_IDLE;
reg [21:0] w_addr = 22'd0;
reg [7:0] w_data = 8'd0;

// the reads in flight: issued (MA out) -> MD in -> byte taken
reg rd1 = 1'b0, rd2 = 1'b0;
reg ram1 = 1'b0, ram2 = 1'b0;
reg lane1 = 1'b0, lane2 = 1'b0;

wire ram_access = cartram_rd | cartram_wr;
wire [21:0] rd_addr = ram_access ? {4'b0001, cartram_addr} : {3'b000, rom_a};

always @(posedge clk) begin
	md_in <= MD_I;

	if (ld_wr) begin
		ld_pend <= 1'b1;
		ld_a <= ld_addr;
		ld_d <= ld_data;
	end

	// the byte of a read issued two clocks ago
	rd2 <= rd1;
	ram2 <= ram1;
	lane2 <= lane1;
	if (rd2) begin
		if (ram2)
			cartram_data <= lane2 ? md_in[15:8] : md_in[7:0];
		else
			rom_do <= lane2 ? md_in[15:8] : md_in[7:0];
	end
	rd1 <= 1'b0;

	case (st)
	S_IDLE: begin
		if (ld_pend && !ld_wr) begin
			ld_pend <= 1'b0;
			w_addr <= {3'b000, ld_a};
			w_data <= ld_d;
			ma_r <= {2'b00, ld_a[18:1]};
			md_out <= {ld_d, ld_d};
			md_oe_n <= 16'h0000;
			mrd_r <= 2'b11;
			st <= S_SETUP;
		end else if (cartram_wr) begin
			w_addr <= {4'b0001, cartram_addr};
			w_data <= cartram_wrdata;
			ma_r <= {3'b000, 1'b1, cartram_addr[17:1]};
			md_out <= {cartram_wrdata, cartram_wrdata};
			md_oe_n <= 16'h0000;
			mrd_r <= 2'b11;
			st <= S_SETUP;
		end else begin
			ma_r <= rd_addr[21:1];
			md_oe_n <= 16'hFFFF;
			mrd_r <= 2'b00;
			rd1 <= 1'b1;
			ram1 <= ram_access;
			lane1 <= rd_addr[0];
		end
	end
	S_SETUP: begin
		mwr_r <= w_addr[0] ? 2'b01 : 2'b10;
		st <= S_WE;
	end
	S_WE: begin
		mwr_r <= 2'b11;
		st <= S_HOLD;
	end
	S_HOLD: begin
		md_oe_n <= 16'hFFFF;
		st <= S_IDLE;
	end
	endcase
end

endmodule
