module audio_channel (
	clk,
	reset,
	aud0,
	aud1,
	volume,
	freq,
	audc,
	audio
);
	input clk;
	input reset;
	input aud0;
	input aud1;
	input [3:0] volume;
	input [4:0] freq;
	input [3:0] audc;
	output wire [3:0] audio;
	wire [4:0] freq_div;
	reg [4:0] freq_latch;
	reg [4:0] freq_next;
	wire freq_match;
	wire freq_div1;
	wire freq_div2;
	wire T1;
	wire T2;
	wire [4:0] noise;
	reg [4:0] noise_latch;
	reg [4:0] noise_next;
	wire noise_wnor_1;
	wire noise_wnor_2;
	wire nor1;
	wire nor2;
	wire nor3;
	wire nor4;
	wire nor5;
	wire nor6;
	wire nor7;
	wire nor8;
	wire and1;
	wire and2;
	wire noise0_latch_n;
	wire nor2_latch;
	wire nor_a;
	wire nor_b;
	wire nor_c;
	wire nor_d;
	wire nor_e;
	wire pulse_bit;
	wire pulse_wnor_1;
	wire pulse_wnor_2;
	wire rnor1;
	wire rnor2;
	wire rnor3;
	wire rand1;
	wire pulse3_q;
	wire pulse2_q;
	wire pulse1_q;
	wire pulse0_q;
	wire pulse3_qn;
	wire pulse2_qn;
	wire pulse1_qn;
	wire pulse0_qn;
	assign freq_div = (aud1 ? (~freq_div2 ? 5'd0 : freq_next) : freq_latch);
	assign freq_match = freq == freq_div;
	inverter_reg freq_div01(
		.clk(clk),
		.reset(reset),
		.set(aud0),
		.in(~freq_match),
		.out(freq_div1)
	);
	inverter_reg freq_div02(
		.clk(clk),
		.reset(reset),
		.set(aud1),
		.in(freq_div1),
		.out(freq_div2)
	);
	assign T1 = ~|{~aud0, freq_div2};
	assign T2 = ~|{~aud1, freq_div1};
	assign nor1 = ~|{~audc[1:0], noise0_latch_n};
	assign nor2 = ~|{nor1, ~audc[1], noise_wnor_1};
	assign nor3 = ~|{audc[1:0], pulse_wnor_1};
	assign nor4 = ~|audc[1:0];
	assign nor5 = ~|{~noise[2], nor4};
	assign nor6 = ~|{nor5, and1};
	assign nor7 = ~|{nor6, noise[0]};
	assign nor8 = ~|{nor_a, nor7, and2, noise_wnor_2};
	assign and1 = nor4 && pulse0_q;
	assign and2 = noise[0] && nor6;
	assign noise_wnor_1 = ~|{noise[4:2], ~noise[1], audc[0], ~audc[1]};
	assign noise_wnor_2 = ~|{noise, nor3};
	assign rnor1 = ~|{pulse_wnor_2, pulse1_q};
	assign rnor2 = ~|{pulse1_q, pulse0_q};
	assign rnor3 = ~|{pulse_wnor_1, rnor2, rand1};
	assign rand1 = pulse1_q && pulse0_q;
	assign nor_a = ~|audc;
	assign nor_b = ~|{audc[3:2], rnor3};
	assign nor_c = ~|{~audc[3:2], rnor1};
	assign nor_d = ~|{audc[3], ~audc[2], pulse3_qn};
	assign nor_e = ~|{~audc[3], audc[2], noise0_latch_n};
	assign pulse_bit = ~|{nor_a, nor_b, nor_c, nor_d, nor_e};
	assign pulse_wnor_1 = ~|{pulse3_qn, pulse2_q, pulse1_qn, pulse0_q};
	assign pulse_wnor_2 = ~|{pulse3_q, pulse2_q, pulse1_q};
	inverter_reg noise0_latch(
		.clk(clk),
		.reset(reset),
		.set(T1),
		.in(~noise[0]),
		.out(noise0_latch_n)
	);
	inverter_reg nor2_l(
		.clk(clk),
		.reset(reset),
		.set(T1),
		.in(nor2),
		.out(nor2_latch)
	);
	wire pulse_clock = ~|{~T2, nor2_latch};
	assign noise = (T2 ? noise_next : noise_latch);
	f_cell pulse_3(
		.clk(clk),
		.reset(reset),
		.tick(pulse_clock),
		.s_n(~pulse_bit),
		.r_n(pulse_bit),
		.q(pulse3_q),
		.q_n(pulse3_qn)
	);
	f_cell pulse_2(
		.clk(clk),
		.reset(reset),
		.tick(pulse_clock),
		.s_n(pulse3_q),
		.r_n(pulse3_qn),
		.q(pulse2_q),
		.q_n(pulse2_qn)
	);
	f_cell pulse_1(
		.clk(clk),
		.reset(reset),
		.tick(pulse_clock),
		.s_n(pulse2_q),
		.r_n(pulse2_qn),
		.q(pulse1_q),
		.q_n(pulse1_qn)
	);
	f_cell pulse_0(
		.clk(clk),
		.reset(reset),
		.tick(pulse_clock),
		.s_n(pulse1_q),
		.r_n(pulse1_qn),
		.q(pulse0_q),
		.q_n(pulse0_qn)
	);
	always @(posedge clk) begin
		if (aud0)
			freq_next <= freq_div + 1'd1;
		if (aud1)
			freq_latch <= (~freq_div2 ? 5'd0 : freq_next);
		if (T1)
			noise_next <= {~nor8, noise_latch[4:1]};
		if (T2)
			noise_latch <= noise_next;
		if (reset) begin
			freq_next <= 0;
			freq_latch <= 0;
			noise_latch <= 0;
			noise_next <= 0;
		end
	end
	assign audio = (~pulse0_qn ? volume : 4'd0);
endmodule
