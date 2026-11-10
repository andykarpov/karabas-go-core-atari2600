module mos6502_alu (
	ai,
	bi,
	sums,
	ands,
	eors,
	ors,
	srs,
	cin,
	daa,
	res,
	acr,
	avr,
	hc
);
	reg _sv2v_0;
	parameter [0:0] BCD_EN = 1;
	input wire [7:0] ai;
	input wire [7:0] bi;
	input wire sums;
	input wire ands;
	input wire eors;
	input wire ors;
	input wire srs;
	input wire cin;
	input wire daa;
	output reg [7:0] res;
	output wire acr;
	output wire avr;
	output wire hc;
	wire [4:0] lo;
	wire [4:0] hi;
	wire [7:0] sum;
	wire dc34;
	assign lo = ({1'b0, ai[3:0]} + {1'b0, bi[3:0]}) + {4'b0000, cin};
	assign dc34 = (BCD_EN && daa) && (lo[4] || (lo[3] && (lo[2] || lo[1])));
	assign hc = lo[4] | dc34;
	assign hi = ({1'b0, ai[7:4]} + {1'b0, bi[7:4]}) + {4'b0000, hc};
	assign sum = {hi[3:0], lo[3:0]};
	wire dc78;
	assign dc78 = (BCD_EN && daa) && (hi[4] || (sum[7] && (sum[6] || sum[5])));
	assign avr = ~(ai[7] ^ bi[7]) & (ai[7] ^ sum[7]);
	assign acr = (srs ? ai[0] & bi[0] : hi[4] | dc78);
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			sums: res = sum;
			ands: res = ai & bi;
			eors: res = ai ^ bi;
			ors: res = ai | bi;
			srs: res = {1'b0, ai[7:1] & bi[7:1]};
			default: res = 8'hff;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
