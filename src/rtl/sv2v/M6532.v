module M6532 (
	clk,
	ce,
	res_n,
	ram_init,
	ram_init_7800,
	addr,
	RW_n,
	d_in,
	d_out,
	RS_n,
	IRQ_n,
	IRQ_n_oe,
	CS1,
	CS2_n,
	PA_in,
	PA_out,
	PB_in,
	PB_out,
	oe,
	PA_read
);
	input clk;
	input ce;
	input res_n;
	input ram_init;
	input ram_init_7800;
	input [6:0] addr;
	input RW_n;
	input [7:0] d_in;
	output wire [7:0] d_out;
	input RS_n;
	output wire IRQ_n;
	output wire IRQ_n_oe;
	input CS1;
	input CS2_n;
	input [7:0] PA_in;
	output wire [7:0] PA_out;
	input [7:0] PB_in;
	output wire [7:0] PB_out;
	output wire [7:0] oe;
	output wire PA_read;
	reg [7:0] out_a;
	reg [7:0] out_b;
	reg [7:0] data;
	reg [7:0] dir_a;
	reg [7:0] dir_b;
	reg [7:0] interrupt;
	reg [7:0] timer;
	reg [9:0] prescaler;
	reg [1:0] incr;
	reg rollover;
	reg [1:0] irq_en;
	reg edge_detect;
	reg old_pa7;
	reg [6:0] init_addr;
	wire [7:0] ram_q;
	reg [7:0] d_out_reg;
	reg ram_read_r;
	wire [1023:0] init_image = 1024'ha900aa85019503e8002ad0f98502a904ea3023a204ca10fd9a8d100120cb0420cb048511851b851c850fea8502a900ea300424033009a90285098d12f1d01e2402300ca90285068d18f18d60f4d00e852ca908851b20cb04ea240230d9a9fd85086cfcffeaffffffffffffffffffffffffffffffffffffffffffffffffff0000;
	wire ram_cpu_wr = (((res_n && ce) && (CS1 & ~CS2_n)) && ~RS_n) && ~RW_n;
	wire [7:0] ram_init_d = (ram_init_7800 ? init_image[(127 - init_addr) * 8+:8] : 8'h00);
	cache_ram_dp #(
		.ADDR_WIDTH(7),
		.DATA_WIDTH(8)
	) riot_ram(
		.clk_i(clk),
		.addr_a_i(addr),
		.wren_a_i(ram_cpu_wr),
		.wdata_a_i(d_in),
		.q_a_o(ram_q),
		.addr_b_i(init_addr),
		.wren_b_i(ram_init),
		.wdata_b_i(ram_init_d),
		.q_b_o()
	);
	wire irq_active = (interrupt[7] & irq_en[1]) | (interrupt[6] & irq_en[0]);
	assign IRQ_n = ~irq_active;
	assign IRQ_n_oe = irq_active;
	assign PA_out = out_a | ~dir_a;
	assign PB_out = out_b | ~dir_b;
	wire pa7 = PA_in[7] & PA_out[7];
	wire p1 = (incr == 2'd0) || rollover;
	wire p8 = ~|prescaler[2:0] && (incr == 2'd1);
	wire p64 = ~|prescaler[5:0] && (incr == 2'd2);
	wire p1024 = ~|prescaler[9:0] && (incr == 2'd3);
	wire tick_inc = ((p1 || p8) || p64) || p1024;
	wire timer_wrap = tick_inc && (timer == 0);
	wire timer_write = ((((CS1 & ~CS2_n) && RS_n) && addr[2]) && addr[4]) && ~RW_n;
	wire pa7_edge = ((edge_detect && ~old_pa7) && pa7) || ((~edge_detect && old_pa7) && ~pa7);
	wire drive = ((res_n && (CS1 & ~CS2_n)) && RW_n) && ce;
	assign oe = {8 {drive}};
	assign PA_read = ((drive && RS_n) && ~addr[2]) && ~|addr[1:0];
	assign d_out = (ram_read_r ? ram_q : d_out_reg);
	always @(posedge clk) begin
		ram_read_r <= ((res_n && (CS1 & ~CS2_n)) && RW_n) && ~RS_n;
		if (ram_read_r)
			d_out_reg <= ram_q;
		if (((CS1 & ~CS2_n) && RW_n) && RS_n) begin
			if (~addr[2])
				case (addr[1:0])
					2'b01: d_out_reg <= dir_a;
					2'b11: d_out_reg <= dir_b;
					2'b00: d_out_reg <= PA_in & PA_out;
					2'b10: d_out_reg <= (dir_b & out_b) | (~dir_b & PB_in);
				endcase
			else if (~addr[0])
				d_out_reg <= (tick_inc ? timer - 8'd1 : timer);
			else
				d_out_reg <= {interrupt[7] | timer_wrap, interrupt[6] | pa7_edge, 6'd0};
		end
		if (~res_n) begin
			d_out_reg <= 8'hff;
			ram_read_r <= 1'b0;
		end
	end
	always @(posedge clk) begin
		if (ram_init)
			init_addr <= init_addr + 1'd1;
		else
			init_addr <= 7'd0;
		if (~res_n) begin
			out_a <= 8'h00;
			out_b <= 8'h00;
			dir_a <= 8'h00;
			dir_b <= 8'h00;
			{interrupt, irq_en, edge_detect} <= 1'sb0;
			old_pa7 <= pa7;
			incr <= 2'b10;
			timer <= 8'hff;
			prescaler <= 0;
			rollover <= 0;
		end
		else if (ce) begin
			prescaler <= prescaler + 1'd1;
			if (tick_inc)
				timer <= timer - 8'd1;
			if (CS1 & ~CS2_n) begin
				if (~RS_n)
					;
				else if (~addr[2]) begin
					if (~RW_n)
						case (addr[1:0])
							2'b01: dir_a <= d_in;
							2'b11: dir_b <= d_in;
							2'b00: out_a <= d_in;
							2'b10: out_b <= d_in;
						endcase
				end
				else if (~RW_n) begin
					if (addr[4]) begin
						prescaler <= 10'd0;
						rollover <= 0;
						interrupt[7] <= 0;
						incr <= addr[1:0];
						timer <= d_in;
						irq_en[1] <= addr[3];
					end
					else begin
						irq_en[0] <= addr[1];
						edge_detect <= addr[0];
					end
				end
				else if (~addr[0]) begin
					irq_en[1] <= addr[3];
					rollover <= 0;
					interrupt[7] <= 0;
				end
				else
					interrupt[6] <= 0;
			end
			if (timer_wrap && !timer_write) begin
				interrupt[7] <= 1;
				rollover <= 1;
			end
			old_pa7 <= pa7;
			if (pa7_edge)
				interrupt[6] <= 1;
		end
	end
endmodule
