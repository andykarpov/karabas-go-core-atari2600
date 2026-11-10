module mos6502_daa (
	sb,
	daa,
	dsa,
	hc,
	acr,
	out
);
	reg _sv2v_0;
	parameter [0:0] BCD_EN = 1;
	input wire [7:0] sb;
	input wire daa;
	input wire dsa;
	input wire hc;
	input wire acr;
	output reg [7:0] out;
	wire add_lo;
	wire sub_lo;
	wire add_hi;
	wire sub_hi;
	assign add_lo = (BCD_EN && daa) && hc;
	assign sub_lo = (BCD_EN && dsa) && !hc;
	assign add_hi = (BCD_EN && daa) && acr;
	assign sub_hi = (BCD_EN && dsa) && !acr;
	always @(*) begin
		if (_sv2v_0)
			;
		out = sb;
		out[1] = sb[1] ^ (add_lo | sub_lo);
		out[2] = sb[2] ^ ((add_lo & ~sb[1]) | (sub_lo & sb[1]));
		out[3] = sb[3] ^ ((add_lo & (sb[1] | sb[2])) | (sub_lo & ~(sb[1] & sb[2])));
		out[5] = sb[5] ^ (add_hi | sub_hi);
		out[6] = sb[6] ^ ((add_hi & ~sb[5]) | (sub_hi & sb[5]));
		out[7] = sb[7] ^ ((add_hi & (sb[5] | sb[6])) | (sub_hi & ~(sb[5] & sb[6])));
	end
	initial _sv2v_0 = 0;
endmodule
