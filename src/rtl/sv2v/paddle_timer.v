module paddle_timer (
	clk,
	ce,
	reset,
	kohms,
	clear,
	read,
	charged,
	difference
);
	input clk;
	input ce;
	input reset;
	input [9:0] kohms;
	input clear;
	input read;
	output reg charged;
	output reg [33:0] difference;
	parameter NS_PER_TICK = 33'd6984;
	localparam CLEAR_NS = 33'd3352320;
	reg [32:0] clear_count;
	reg [32:0] high_count;
	reg [32:0] lowest;
	reg [32:0] highest;
	reg [1:0] read_count;
	reg old_read;
	wire read_measured = &read_count;
	reg [32:0] width = 0;
	reg cleared = 0;
	always @(posedge clk)
		if (ce) begin
			old_read <= clear;
			if (~read_measured && (clear && ~old_read))
				read_count <= read_count + 1'd1;
			if (clear) begin
				if (clear_count < CLEAR_NS)
					clear_count <= clear_count + NS_PER_TICK;
				else begin
					cleared <= 1;
					high_count <= 0;
					charged <= 0;
				end
			end
			else begin
				clear_count <= 0;
				if (high_count < difference)
					high_count <= high_count + NS_PER_TICK;
				else
					charged <= 1;
				if (cleared) begin
					if (read && (highest < high_count))
						highest <= high_count;
					if (read && (high_count < lowest)) begin
						lowest <= high_count;
						highest <= 1'sb0;
						read_count <= 2'b00;
					end
					if (lowest < highest)
						width <= highest - lowest;
				end
				difference <= ((lowest > highest) | ~read_measured ? 33'h114b6c376 : lowest + (((width + {NS_PER_TICK, 1'b0}) >> 4'd8) * kohms[7:0]));
			end
			if (reset) begin
				cleared <= 0;
				width <= 0;
				read_count <= 0;
				lowest <= {33 {1'b1}};
				highest <= 1'sb0;
				difference <= 1'sb0;
			end
		end
endmodule
