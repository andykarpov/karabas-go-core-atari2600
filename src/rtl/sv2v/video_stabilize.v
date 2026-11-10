module video_stabilize (
	clk,
	reset,
	oclk,
	mode,
	vsync_in,
	vblank_in,
	hsync_in,
	hblank_in,
	vsync,
	vblank,
	auto_pal,
	f1
);
	input clk;
	input reset;
	input wire [4:0] oclk;
	input [1:0] mode;
	input vsync_in;
	input vblank_in;
	input hsync_in;
	input hblank_in;
	output wire vsync;
	output wire vblank;
	output wire auto_pal;
	output wire f1;
	localparam ntsc_vb_end = 9'd19;
	localparam pal_vb_end = 9'd23;
	localparam ntsc_vb_start = 9'd240 + ntsc_vb_end;
	localparam pal_vb_start = 9'd288 + pal_vb_end;
	localparam [8:0] lines_absurd = 9'd412;
	localparam [5:0] score_span = 6'd50;
	localparam [5:0] garbage_frames = 6'd8;
	localparam [5:0] detect_frames = 6'd40;
	reg [8:0] v_count;
	reg [8:0] total_lines;
	reg [8:0] vsync_line;
	wire [8:0] vsync_end_line;
	wire [7:0] h_count;
	reg old_hblank;
	wire old_vblank;
	wire old_hsync;
	reg old_vsync;
	reg vsync_en;
	reg vsync_set;
	reg vblank_en;
	wire midline_sync;
	reg vsync_override;
	wire set_end;
	reg [7:0] vsync_count;
	wire [7:0] vblank_count;
	wire [7:0] lines_from_vs;
	reg [7:0] dot_count = 0;
	reg vsync_emulate;
	reg pal_mode;
	reg region_done;
	reg [5:0] region_frames;
	reg [11:0] pal_sum;
	reg [11:0] ntsc_sum;
	wire hblank_start = ~old_hblank && hblank_in;
	wire hblank_end = old_hblank && ~hblank_in;
	wire vsync_start = ~old_vsync && vsync_in;
	assign vblank = (|mode ? vblank_in : vblank_en);
	assign vsync = (|mode ? vsync_in : vsync_en);
	assign f1 = 1'b0;
	assign auto_pal = pal_mode;
	wire [8:0] over_ntsc = (v_count > 9'd262 ? v_count - 9'd262 : 9'd0);
	wire [5:0] score_raw = (over_ntsc >= 9'h032 ? score_span : over_ntsc[5:0]);
	wire [5:0] frame_score = (v_count[0] ? {1'b0, score_raw[5:1]} : score_raw);
	always @(posedge clk) begin
		old_hblank <= hblank_in;
		old_vsync <= vsync_in;
		if (&v_count) begin
			total_lines <= 9'd262;
			vsync_override <= 1'd1;
			vsync_emulate <= 1'd1;
		end
		if (hblank_start) begin
			v_count <= v_count + 1'd1;
			if (v_count == (auto_pal ? pal_vb_end : ntsc_vb_end))
				vblank_en <= 0;
			if ((v_count == (auto_pal ? pal_vb_start : ntsc_vb_start)) || (v_count == ((vsync_override ? vsync_line : total_lines) - 4'd4)))
				vblank_en <= 1;
			if ((vsync_override && (v_count == (vsync_line - 1'd1))) || vsync_set) begin
				if (vsync_emulate)
					v_count <= 0;
				vsync_en <= 1;
				vsync_set <= 0;
				vblank_en <= 1;
				if (~|vsync_count)
					vsync_count <= 3'd3;
			end
			if (|vsync_count) begin
				vsync_count <= vsync_count - 1'd1;
				if (vsync_count == 1)
					vsync_en <= 0;
			end
		end
		if (oclk[4])
			dot_count <= dot_count + 1'd1;
		if (hblank_end)
			dot_count <= 0;
		if (vsync_start) begin
			vsync_emulate <= 0;
			if (v_count != total_lines) begin
				vsync_set <= 1;
				if ((total_lines - v_count) < 3'd4) begin
					vsync_override <= 1;
					vsync_line <= v_count;
				end
				else if ((v_count - total_lines) < 3'd4) begin
					vsync_override <= 1;
					vsync_line <= total_lines;
				end
				else
					vsync_override <= 0;
			end
			if (~vsync_override)
				vsync_set <= 1;
			v_count <= 0;
			total_lines <= v_count;
			if (!region_done) begin
				region_frames <= region_frames + 1'd1;
				if ((region_frames >= garbage_frames) && (v_count <= lines_absurd)) begin
					pal_sum <= pal_sum + {6'b000000, frame_score};
					ntsc_sum <= ntsc_sum + {6'b000000, score_span - frame_score};
				end
				if (region_frames == (garbage_frames + detect_frames)) begin
					pal_mode <= pal_sum > ntsc_sum;
					region_done <= 1'b1;
				end
			end
		end
		if (reset) begin
			vsync_emulate <= 0;
			dot_count <= 0;
			vsync_set <= 0;
			vsync_line <= 0;
			vsync_override <= 0;
			total_lines <= 9'd262;
			pal_mode <= 1'b0;
			region_done <= 1'b0;
			region_frames <= 6'd0;
			pal_sum <= 12'd0;
			ntsc_sum <= 12'd0;
			v_count <= 0;
			vblank_en <= 1;
			vsync_en <= 0;
		end
	end
endmodule
