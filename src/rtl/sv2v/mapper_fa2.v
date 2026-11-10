module mapper_fa2 (
	clk,
	reset,
	ce,
	phi1,
	a_change,
	a_in,
	d_in,
	rom_data,
	rom_size,
	d_out,
	flags_out,
	oe,
	rom_a,
	nvram_request,
	nvram_write,
	nvram_addr,
	nvram_wdata,
	nvram_rdata,
	nvram_ready,
	nvram_dirty
);
	reg _sv2v_0;
	parameter [18:0] READ_TICKS = 19'd1790;
	parameter [18:0] WRITE_TICKS = 19'd361535;
	input wire clk;
	input wire reset;
	input wire ce;
	input wire phi1;
	input wire a_change;
	input wire [12:0] a_in;
	input wire [7:0] d_in;
	input wire [7:0] rom_data;
	input wire [31:0] rom_size;
	output reg [7:0] d_out;
	output reg [15:0] flags_out;
	output reg [7:0] oe;
	output reg [18:0] rom_a;
	output reg nvram_request;
	output reg nvram_write;
	output reg [7:0] nvram_addr;
	output reg [7:0] nvram_wdata;
	input wire [7:0] nvram_rdata;
	input wire nvram_ready;
	output reg nvram_dirty;
	localparam [2:0] COPY_NONE = 3'd0;
	localparam [2:0] COPY_LOAD_REQ = 3'd1;
	localparam [2:0] COPY_LOAD_NEXT = 3'd2;
	localparam [2:0] COPY_SAVE_READ = 3'd3;
	localparam [2:0] COPY_SAVE_REQ = 3'd4;
	reg [2:0] bank;
	reg [2:0] copy_state;
	reg [7:0] copy_addr;
	reg [18:0] timer;
	reg operation_active;
	reg command_pending;
	reg ready_response;
	reg [7:0] ram_addr;
	reg [7:0] ram_wdata;
	wire [7:0] ram_q;
	reg ram_wren;
	wire ram_write_port = a_in[12:8] == 5'h10;
	wire ram_read_port = a_in[12:8] == 5'h11;
	wire harmony_image = rom_size >= 32'd29696;
	wire padded_bank = (rom_size == 32'd24576) && (bank == 3'd6);
	wire flash_hotspot = a_in == 13'h1ff4;
	wire operation_done = (operation_active && (timer == 19'd0)) && (copy_state == COPY_NONE);
	wire success_poll = (operation_done && a_change) && flash_hotspot;
	wire cpu_ram_write = (((copy_state == COPY_NONE) && ram_write_port) && !phi1) && !a_change;
	always @(*) begin
		if (_sv2v_0)
			;
		ram_addr = a_in[7:0];
		ram_wdata = d_in;
		ram_wren = cpu_ram_write;
		if (copy_state != COPY_NONE)
			ram_addr = copy_addr;
		else if (command_pending || flash_hotspot)
			ram_addr = 8'hff;
		if ((copy_state == COPY_LOAD_REQ) && nvram_ready) begin
			ram_wdata = nvram_rdata;
			ram_wren = 1'b1;
		end
		else if (success_poll) begin
			ram_addr = 8'hff;
			ram_wdata = 8'h00;
			ram_wren = 1'b1;
		end
	end
	spram #(
		.addr_width(8),
		.data_width(8),
		.mem_name("FA2_WORK_RAM")
	) working_ram(
		.clock(clk),
		.address(ram_addr),
		.data(ram_wdata),
		.wren(ram_wren),
		.q(ram_q),
		.cs(1'b1)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		nvram_request = (copy_state == COPY_LOAD_REQ) || (copy_state == COPY_SAVE_REQ);
		nvram_write = copy_state == COPY_SAVE_REQ;
		nvram_addr = copy_addr;
		nvram_wdata = ram_q;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		flags_out = 16'd0;
		d_out = 8'd0;
		oe = (a_in[12] && !ram_write_port ? 8'hff : 8'h00);
		if (ram_read_port) begin
			flags_out[0] = 1'b1;
			d_out = ram_q;
		end
		else if (flash_hotspot) begin
			flags_out[0] = 1'b1;
			if (ready_response || operation_done)
				d_out = rom_data & 8'hbf;
			else
				d_out = rom_data | 8'h40;
		end
		else if (padded_bank) begin
			flags_out[0] = 1'b1;
			d_out = 8'h00;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		rom_a = {4'd0, bank, a_in[11:0]};
		if (harmony_image)
			rom_a = rom_a + 19'd1024;
	end
	always @(posedge clk) begin
		nvram_dirty <= 1'b0;
		if ((timer != 19'd0) && ce)
			timer <= timer - 19'd1;
		if ((ready_response && a_change) && !flash_hotspot)
			ready_response <= 1'b0;
		if (((!operation_active && !ready_response) && a_change) && flash_hotspot)
			command_pending <= 1'b1;
		if (command_pending) begin
			command_pending <= 1'b0;
			operation_active <= 1'b1;
			copy_addr <= 8'd0;
			case (ram_q)
				8'd1: begin
					timer <= READ_TICKS;
					copy_state <= COPY_LOAD_REQ;
				end
				8'd2: begin
					timer <= WRITE_TICKS;
					copy_state <= COPY_SAVE_READ;
				end
				default: begin
					timer <= 19'd0;
					copy_state <= COPY_NONE;
				end
			endcase
		end
		case (copy_state)
			COPY_LOAD_REQ:
				if (nvram_ready) begin
					if (copy_addr == 8'hff)
						copy_state <= COPY_NONE;
					else begin
						copy_addr <= copy_addr + 8'd1;
						copy_state <= COPY_LOAD_NEXT;
					end
				end
			COPY_LOAD_NEXT: copy_state <= COPY_LOAD_REQ;
			COPY_SAVE_READ: copy_state <= COPY_SAVE_REQ;
			COPY_SAVE_REQ:
				if (nvram_ready) begin
					if (copy_addr == 8'hff) begin
						copy_state <= COPY_NONE;
						nvram_dirty <= 1'b1;
					end
					else begin
						copy_addr <= copy_addr + 8'd1;
						copy_state <= COPY_SAVE_READ;
					end
				end
			default:
				;
		endcase
		if (success_poll) begin
			operation_active <= 1'b0;
			ready_response <= 1'b1;
		end
		if (a_change)
			case (a_in)
				13'h1ff5: bank <= 3'd0;
				13'h1ff6: bank <= 3'd1;
				13'h1ff7: bank <= 3'd2;
				13'h1ff8: bank <= 3'd3;
				13'h1ff9: bank <= 3'd4;
				13'h1ffa: bank <= 3'd5;
				13'h1ffb: bank <= 3'd6;
				default:
					;
			endcase
		if (reset) begin
			bank <= 3'd0;
			copy_state <= COPY_NONE;
			copy_addr <= 8'd0;
			timer <= 19'd0;
			operation_active <= 1'b0;
			command_pending <= 1'b0;
			ready_response <= 1'b0;
			nvram_dirty <= 1'b0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
