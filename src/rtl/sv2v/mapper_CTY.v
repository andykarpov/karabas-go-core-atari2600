module mapper_CTY (
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
	ce,
	rom_do
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
	input ce;
	input [7:0] rom_do;
	localparam [21:0] READ_DELAY = 22'd1789772;
	localparam [21:0] WRITE_DELAY = 22'd3579545;
	reg [2:0] bank;
	reg [7:0] operation;
	reg [7:0] error_code;
	reg [31:0] random;
	reg [15:0] tune_pos;
	reg busy;
	reg [21:0] busy_timer;
	wire [5:0] index = a_in[5:0];
	wire is_ram = a_in[12] && ~|a_in[11:7];
	wire write_port = is_ram && ~a_in[6];
	wire read_port = is_ram && a_in[6];
	wire is_reg = ~|index[5:2];
	wire flash_sel = a_in == 13'h1ff4;
	wire [31:0] random_next = {random[10:0], random[31:11]} ^ (random[10] ? 32'h10adab1e : 32'd0);
	reg [7:0] reg_do;
	always @(*) begin
		if (_sv2v_0)
			;
		case (index[1:0])
			2'd0: reg_do = error_code;
			2'd1: reg_do = random_next[7:0];
			2'd2: reg_do = tune_pos[7:0];
			2'd3: reg_do = tune_pos[15:8];
		endcase
	end
	assign flags_out = {15'd0, flash_sel || (read_port && is_reg)};
	assign d_out = (flash_sel ? (busy ? rom_do | 8'h40 : rom_do & 8'hbf) : reg_do);
	assign oe = (a_in[12] ? (write_port ? 8'h00 : 8'hff) : 8'h00);
	assign ram_sel = is_ram && ~is_reg;
	assign ram_rw = read_port;
	assign ram_a = {12'd0, index};
	assign rom_a = {4'd0, bank, a_in[11:0]};
	always @(posedge clk) begin
		if (ce && |busy_timer)
			busy_timer <= busy_timer - 1'd1;
		if (a_change) begin
			if (((a_in[12:4] == 9'h1ff) && (a_in[3:0] >= 4'h5)) && (a_in[3:0] <= 4'hb))
				bank <= a_in[3:0] - 4'd4;
			if (flash_sel) begin
				if (~busy) begin
					busy <= 1'b1;
					busy_timer <= ((operation[3:0] == 4'd3) || (operation[3:0] == 4'd4) ? WRITE_DELAY : READ_DELAY);
				end
				else if (~|busy_timer) begin
					busy <= 1'b0;
					error_code <= 8'h00;
				end
			end
			if (write_port && is_reg)
				case (index[1:0])
					2'd0: operation <= d_in;
					2'd1: random <= 32'h2b435044;
					2'd2: tune_pos <= 16'd0;
					2'd3: tune_pos <= tune_pos + 1'd1;
				endcase
			if ((read_port && is_reg) && (index[1:0] == 2'd1))
				random <= random_next;
		end
		if (reset) begin
			bank <= 3'd1;
			operation <= 8'd0;
			error_code <= 8'hff;
			random <= 32'h2b435044;
			tune_pos <= 16'd0;
			busy <= 1'b0;
			busy_timer <= 22'd0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
