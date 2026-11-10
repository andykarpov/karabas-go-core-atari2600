module mos6502_ctl (
	clk_sys,
	phi1_en,
	phi2_en,
	res_n,
	rdy,
	irq_n,
	nmi_n,
	so_n,
	data_in,
	p,
	acr_now,
	dl,
	c,
	ir,
	sync,
	jammed,
	dbg_t,
	dbg_hold,
	dbg_int_active,
	dbg_res_active,
	dbg_tg,
	dbg_take_int
);
	reg _sv2v_0;
	parameter [0:0] BCD_EN = 1'b1;
	input wire clk_sys;
	input wire phi1_en;
	input wire phi2_en;
	input wire res_n;
	input wire rdy;
	input wire irq_n;
	input wire nmi_n;
	input wire so_n;
	input wire [7:0] data_in;
	input wire [7:0] p;
	input wire acr_now;
	input wire [7:0] dl;
	output reg [75:0] c;
	output reg [7:0] ir;
	output wire sync;
	output wire jammed;
	output wire [3:0] dbg_t;
	output wire dbg_hold;
	output wire dbg_int_active;
	output wire dbg_res_active;
	output wire [15:0] dbg_tg;
	output wire dbg_take_int;
	reg [3:0] t = 4'd1;
	reg [75:0] c_reg;
	wire [3:0] nt;
	reg [75:0] nc;
	wire [24:0] d;
	mos6502_decode decode(
		.ir(ir),
		.d(d)
	);
	reg int_g;
	reg res_g;
	reg int_armed;
	wire int_active;
	wire res_active;
	assign res_active = res_g;
	assign int_active = int_g | res_g;
	wire nmi_pending;
	wire res_now;
	reg res_c2 = 1'b1;
	assign res_now = res_g | res_c2;
	reg so_last;
	wire sh_store;
	assign sh_store = (((d[9-:4] == 4'd5) || (d[9-:4] == 4'd6)) || (d[9-:4] == 4'd7)) || (d[9-:4] == 4'd8);
	reg pgx;
	reg idx_cross_q;
	wire br_take;
	wire br_back;
	wire br_fix;
	reg [1:0] n_pc_src;
	wire hold;
	wire res_no_prefetch;
	reg sync_q;
	assign sync = (hold ? sync_q : t == 4'd1) & ~res_no_prefetch;
	assign jammed = (d[24-:5] == 5'd20) && (t >= 4'd2);
	assign dbg_t = t;
	assign dbg_hold = hold;
	assign dbg_int_active = int_active;
	assign dbg_res_active = res_active;
	reg end_x_q;
	wire ext_t5;
	wire ext_t6;
	reg res_p = 1'b1;
	wire t_zero;
	reg [5:0] tg;
	assign dbg_tg = {4'd0, res_no_prefetch, res_p, end_x_q, t_zero, ext_t6, ext_t5, tg};
	wire take_int;
	assign dbg_take_int = take_int;
	wire pd_implied;
	assign pd_implied = (data_in[3] & ~data_in[2]) & ~data_in[0];
	reg pd_two_cycle;
	always @(*) begin : sv2v_autoblock_1
		reg imp;
		reg m_xxx010x1;
		reg m_1xx000x0;
		reg m_0xx01000;
		if (_sv2v_0)
			;
		imp = (ir[3] & ~ir[2]) & ~ir[0];
		m_xxx010x1 = ((~ir[4] & ir[3]) & ~ir[2]) & ir[0];
		m_1xx000x0 = (((ir[7] & ~ir[4]) & ~ir[3]) & ~ir[2]) & ~ir[0];
		m_0xx01000 = ((((~ir[7] & ~ir[4]) & ir[3]) & ~ir[2]) & ~ir[1]) & ~ir[0];
		pd_two_cycle = (m_xxx010x1 | m_1xx000x0) | (imp & ~m_0xx01000);
	end
	localparam [75:0] mos6502_pkg_CTL_IDLE = 1'sb0;
	function automatic [75:0] addr_pc;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[71] = 1'b1;
			r[69] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_pc = r;
		end
	endfunction
	function automatic [75:0] addr_zp;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[74] = 1'b1;
			r[55] = 1'b1;
			r[54] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_zp = r;
		end
	endfunction
	function automatic [75:0] addr_zp_add;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[60] = 1'b1;
			r[55] = 1'b1;
			r[54] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_zp_add = r;
		end
	endfunction
	function automatic [75:0] addr_stack;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[67] = 1'b1;
			r[54] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_stack = r;
		end
	endfunction
	function automatic [75:0] addr_dl_add;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[60] = 1'b1;
			r[73] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_dl_add = r;
		end
	endfunction
	function automatic [75:0] addr_fix_hi;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[62] = 1'b1;
			r[61] = 1'b1;
			r[52] = 1'b1;
			r[34] = 1'b1;
			addr_fix_hi = r;
		end
	endfunction
	function automatic [75:0] addr_add_pch;
		input reg _sv2v_unused;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[60] = 1'b1;
			r[69] = 1'b1;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_add_pch = r;
		end
	endfunction
	function automatic [75:0] addr_vector;
		input reg hi;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[58] = ~hi;
			r[57] = res_now;
			r[56] = nmi_pending & ~res_now;
			r[35] = 1'b1;
			r[34] = 1'b1;
			addr_vector = r;
		end
	endfunction
	function automatic [75:0] alu_index;
		input reg use_x;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			if (use_x)
				r[66] = 1'b1;
			else
				r[65] = 1'b1;
			r[44] = 1'b1;
			r[75] = 1'b1;
			r[42] = 1'b1;
			r[33] = 1'b1;
			alu_index = r;
		end
	endfunction
	function automatic [75:0] alu_fix;
		input reg carry;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[43] = 1'b1;
			r[75] = 1'b1;
			r[42] = 1'b1;
			r[33] = 1'b1;
			r[28] = carry;
			alu_fix = r;
		end
	endfunction
	function automatic [75:0] op_a;
		input reg [24:0] o;
		reg [75:0] r;
		reg combo;
		begin
			r = mos6502_pkg_CTL_IDLE;
			combo = ((o[17-:3] != 3'd0) && (o[14-:5] != 5'd0)) && (o[24-:5] != 5'd1);
			if (combo)
				(* full_case, parallel_case *)
				case (o[14-:5])
					5'd1: begin
						r[64] = 1;
						r[44] = 1;
						r[30] = 1;
					end
					5'd2: begin
						r[64] = 1;
						r[44] = 1;
						r[32] = 1;
					end
					5'd3: begin
						r[64] = 1;
						r[44] = 1;
						r[31] = 1;
					end
					5'd4: begin
						r[64] = 1;
						r[44] = 1;
						r[33] = 1;
						r[28] = p[0];
						r[27] = BCD_EN & p[3];
					end
					5'd5: begin
						r[64] = 1;
						r[44] = 1;
						r[33] = 1;
						r[28] = p[0];
						r[26] = BCD_EN & p[3];
					end
					5'd6: begin
						r[64] = 1;
						r[44] = 1;
						r[33] = 1;
						r[28] = 1;
					end
					default:
						;
				endcase
			else begin
				(* full_case, parallel_case *)
				case (o[14-:5])
					5'd9: begin
						r[75] = 1;
						r[53] = 1;
						r[45] = 1;
						r[18] = 1;
						r[17] = 1;
					end
					5'd10: begin
						r[75] = 1;
						r[53] = 1;
						r[51] = 1;
						r[18] = 1;
						r[17] = 1;
					end
					5'd11: begin
						r[75] = 1;
						r[53] = 1;
						r[50] = 1;
						r[18] = 1;
						r[17] = 1;
					end
					5'd12: begin
						r[75] = 1;
						r[53] = 1;
						r[45] = 1;
						r[51] = 1;
						r[18] = 1;
						r[17] = 1;
					end
					5'd1: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[30] = 1;
					end
					5'd2: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
					end
					5'd14: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
					end
					5'd15: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[29] = 1;
					end
					5'd16: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[29] = 1;
						r[24] = BCD_EN & p[3];
					end
					5'd20: begin
						r[68] = 1;
						r[44] = 1;
						r[51] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
					end
					5'd18: begin
						r[64] = 1;
						r[66] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
					end
					5'd19: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
					end
					5'd3: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[31] = 1;
					end
					5'd4: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[33] = 1;
						r[28] = p[0];
						r[27] = BCD_EN & p[3];
					end
					5'd5: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[41] = 1;
						r[33] = 1;
						r[28] = p[0];
						r[26] = BCD_EN & p[3];
					end
					5'd6: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[41] = 1;
						r[33] = 1;
						r[28] = 1;
					end
					5'd7: begin
						r[66] = 1;
						r[44] = 1;
						r[75] = 1;
						r[41] = 1;
						r[33] = 1;
						r[28] = 1;
					end
					5'd8: begin
						r[65] = 1;
						r[44] = 1;
						r[75] = 1;
						r[41] = 1;
						r[33] = 1;
						r[28] = 1;
					end
					5'd13: begin
						r[64] = 1;
						r[44] = 1;
						r[75] = 1;
						r[42] = 1;
						r[32] = 1;
						r[18] = 1;
						r[14] = 1;
					end
					5'd17: begin
						r[64] = 1;
						r[66] = 1;
						r[44] = 1;
						r[75] = 1;
						r[41] = 1;
						r[33] = 1;
						r[28] = 1;
					end
					default:
						;
				endcase
				if (o[24-:5] == 5'd1) begin
					r[64] = 1;
					r[44] = 1;
					r[63] = 1;
					r[42] = 1;
					(* full_case, parallel_case *)
					case (o[17-:3])
						3'd1: r[33] = 1;
						3'd3: begin
							r[33] = 1;
							r[28] = p[0];
						end
						3'd2: r[29] = 1;
						3'd4: r[29] = 1;
						default:
							;
					endcase
				end
				if (o[24-:5] == 5'd19) begin
					r[75] = 1;
					if (ir[6]) begin
						r[53] = 1;
						r[45] = 1;
						r[18] = 1;
						r[17] = 1;
					end
					else begin
						r[2] = 1;
						r[21] = 1;
						r[14] = 1;
						r[18] = 1;
					end
				end
				if (o[24-:5] == 5'd0)
					(* full_case, parallel_case *)
					case (o[5-:5])
						5'd1: begin
							r[64] = 1;
							r[53] = 1;
							r[51] = 1;
							r[18] = 1;
							r[17] = 1;
						end
						5'd2: begin
							r[64] = 1;
							r[53] = 1;
							r[50] = 1;
							r[18] = 1;
							r[17] = 1;
						end
						5'd3: begin
							r[66] = 1;
							r[53] = 1;
							r[45] = 1;
							r[18] = 1;
							r[17] = 1;
						end
						5'd4: begin
							r[65] = 1;
							r[53] = 1;
							r[45] = 1;
							r[18] = 1;
							r[17] = 1;
						end
						5'd5: begin
							r[68] = 1;
							r[53] = 1;
							r[51] = 1;
							r[18] = 1;
							r[17] = 1;
						end
						5'd6: begin
							r[66] = 1;
							r[49] = 1;
						end
						5'd7: begin
							r[66] = 1;
							r[44] = 1;
							r[41] = 1;
							r[33] = 1;
							r[28] = 1;
						end
						5'd8: begin
							r[65] = 1;
							r[44] = 1;
							r[41] = 1;
							r[33] = 1;
							r[28] = 1;
						end
						5'd9: begin
							r[66] = 1;
							r[44] = 1;
							r[42] = 1;
							r[33] = 1;
						end
						5'd10: begin
							r[65] = 1;
							r[44] = 1;
							r[42] = 1;
							r[33] = 1;
						end
						5'd11, 5'd12: r[20] = 1;
						5'd13, 5'd14: r[16] = 1;
						5'd15, 5'd16: r[15] = 1;
						5'd17: r[11] = 1;
						default:
							;
					endcase
			end
			op_a = r;
		end
	endfunction
	function automatic [75:0] op_b;
		input reg [24:0] o;
		reg [75:0] r;
		reg wrote;
		begin
			r = mos6502_pkg_CTL_IDLE;
			wrote = 1'b0;
			(* full_case, parallel_case *)
			case (o[14-:5])
				5'd1, 5'd2, 5'd3: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					wrote = 1;
				end
				5'd4: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					r[19] = 1;
					r[13] = 1;
					r[27] = BCD_EN & p[3];
					wrote = 1;
				end
				5'd5: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					r[19] = 1;
					r[13] = 1;
					r[26] = BCD_EN & p[3];
					wrote = 1;
				end
				5'd6, 5'd7, 5'd8: begin
					r[18] = 1;
					r[17] = 1;
					r[19] = 1;
					wrote = 1;
				end
				5'd13: begin
					r[17] = 1;
					wrote = 1;
				end
				5'd14: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					r[9] = 1;
					wrote = 1;
				end
				5'd15: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					r[19] = 1;
					wrote = 1;
				end
				5'd16: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					r[8] = 1;
					r[23] = BCD_EN & p[3];
					wrote = 1;
				end
				5'd20: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					wrote = 1;
				end
				5'd18: begin
					r[45] = 1;
					r[18] = 1;
					r[17] = 1;
					wrote = 1;
				end
				5'd19: begin
					r[45] = 1;
					r[51] = 1;
					r[18] = 1;
					r[17] = 1;
					wrote = 1;
				end
				5'd17: begin
					r[51] = 1;
					r[18] = 1;
					r[17] = 1;
					r[19] = 1;
					wrote = 1;
				end
				default:
					;
			endcase
			if (o[24-:5] == 5'd1) begin
				r[45] = 1;
				r[18] = 1;
				r[17] = 1;
				r[19] = 1;
				wrote = 1;
			end
			if (o[24-:5] == 5'd0)
				(* full_case, parallel_case *)
				case (o[5-:5])
					5'd7, 5'd9: begin
						r[51] = 1;
						r[18] = 1;
						r[17] = 1;
						wrote = 1;
					end
					5'd8, 5'd10: begin
						r[50] = 1;
						r[18] = 1;
						r[17] = 1;
						wrote = 1;
					end
					default:
						;
				endcase
			if (wrote) begin
				r[62] = 1;
				r[61] = (((o[24-:5] == 5'd1) && (o[17-:3] == 3'd4)) || (o[14-:5] == 5'd16) ? ~p[0] : 1'b1);
				r[53] = 1;
			end
			op_b = r;
		end
	endfunction
	function automatic [75:0] op_rmw;
		input reg [2:0] k;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[75] = 1;
			r[42] = 1;
			(* full_case, parallel_case *)
			case (k)
				3'd1: begin
					r[53] = 1;
					r[44] = 1;
					r[33] = 1;
				end
				3'd3: begin
					r[53] = 1;
					r[44] = 1;
					r[33] = 1;
					r[28] = p[0];
				end
				3'd2: begin
					r[53] = 1;
					r[44] = 1;
					r[29] = 1;
				end
				3'd4: begin
					r[53] = 1;
					r[44] = 1;
					r[29] = 1;
				end
				3'd5: begin
					r[43] = 1;
					r[33] = 1;
					r[28] = 1;
				end
				3'd6: begin
					r[44] = 1;
					r[33] = 1;
				end
				default:
					;
			endcase
			op_rmw = r;
		end
	endfunction
	function automatic [75:0] rmw_out;
		input reg [2:0] k;
		input reg [4:0] dop;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			r[62] = 1;
			r[61] = (k == 3'd4 ? ~p[0] : 1'b1);
			r[53] = 1;
			r[18] = 1;
			r[17] = 1;
			if ((k != 3'd5) && (k != 3'd6))
				r[19] = 1;
			if ((dop == 5'd6) || (dop == 5'd5))
				r[41] = 1;
			else if (dop != 5'd0)
				r[42] = 1;
			rmw_out = r;
		end
	endfunction
	function automatic [75:0] store_out;
		input reg [3:0] k;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			(* full_case, parallel_case *)
			case (k)
				4'd1: r[63] = 1;
				4'd2: begin
					r[66] = 1;
					r[53] = 1;
				end
				4'd3: begin
					r[65] = 1;
					r[53] = 1;
				end
				4'd4: begin
					r[63] = 1;
					r[66] = 1;
					r[53] = 1;
				end
				4'd5, 4'd8: begin
					r[63] = 1;
					r[66] = 1;
					r[53] = 1;
					r[62] = 1;
					r[61] = 1;
				end
				4'd6: begin
					r[66] = 1;
					r[53] = 1;
					r[62] = 1;
					r[61] = 1;
				end
				4'd7: begin
					r[65] = 1;
					r[53] = 1;
					r[62] = 1;
					r[61] = 1;
				end
				default:
					;
			endcase
			store_out = r;
		end
	endfunction
	function automatic [75:0] store_sh;
		input reg [3:0] k;
		input reg crossed;
		reg [75:0] r;
		begin
			r = store_out(k);
			r[0] = 1'b1;
			if (crossed) begin
				r[52] = 1'b1;
				r[34] = 1'b1;
			end
			store_sh = r;
		end
	endfunction
	function automatic [75:0] seq;
		input reg [24:0] o;
		input reg [3:0] n;
		input reg idx_crossed;
		reg [75:0] r;
		begin
			r = mos6502_pkg_CTL_IDLE;
			(* full_case, parallel_case *)
			case (o[24-:5])
				5'd3:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_zp(0);
							if (o[19-:2] == 2'd1) begin
								r[0] = 1;
								r = r | store_out(o[9-:4]);
							end
						end
						4'd4: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd5: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd4, 5'd5:
					(* full_case, parallel_case *)
					case (n)
						4'd3: r = addr_zp(0) | alu_index(o[24-:5] == 5'd4);
						4'd4: begin
							r = addr_zp_add(0);
							if (o[19-:2] == 2'd1) begin
								r[0] = 1;
								r = r | store_out(o[9-:4]);
							end
						end
						4'd5: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd6: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd6:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_pc(0);
							r[38] = 1;
							r[36] = 1;
							r[22] = 1;
							r = r | alu_fix(1'b0);
						end
						4'd4: begin
							r = addr_dl_add(0);
							if (o[19-:2] == 2'd1) begin
								r[0] = 1;
								r = r | store_out(o[9-:4]);
							end
						end
						4'd5: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd6: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd7, 5'd8:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_pc(0);
							r[38] = 1;
							r[36] = 1;
							r[22] = 1;
							r = r | alu_index(o[24-:5] == 5'd7);
						end
						4'd4: begin
							r = addr_dl_add(0) | alu_fix((sh_store ? 1'b1 : acr_now));
							if (o[9-:4] == 4'd8) begin
								r[64] = 1;
								r[66] = 1;
								r[49] = 1;
							end
						end
						4'd5:
							if (sh_store)
								r = store_sh(o[9-:4], idx_crossed);
							else begin
								r = addr_fix_hi(0);
								if (o[19-:2] == 2'd1) begin
									r[0] = 1;
									r = r | store_out(o[9-:4]);
								end
							end
						4'd6: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd7: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd9:
					(* full_case, parallel_case *)
					case (n)
						4'd3: r = addr_zp(0) | alu_index(1'b1);
						4'd4: begin
							r = addr_zp_add(0);
							r[62] = 1;
							r[61] = 1;
							r[44] = 1;
							r[41] = 1;
							r[33] = 1;
							r[28] = 1;
						end
						4'd5: r = addr_zp_add(0) | alu_fix(1'b0);
						4'd6: begin
							r = addr_dl_add(0);
							if (o[19-:2] == 2'd1) begin
								r[0] = 1;
								r = r | store_out(o[9-:4]);
							end
						end
						4'd7: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd8: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd10:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_zp(0);
							r[43] = 1;
							r[75] = 1;
							r[42] = 1;
							r[33] = 1;
							r[28] = 1;
						end
						4'd4: r = addr_zp_add(0) | alu_index(1'b0);
						4'd5: r = addr_dl_add(0) | alu_fix((sh_store ? 1'b1 : acr_now));
						4'd6:
							if (sh_store)
								r = store_sh(o[9-:4], idx_crossed);
							else begin
								r = addr_fix_hi(0);
								if (o[19-:2] == 2'd1) begin
									r[0] = 1;
									r = r | store_out(o[9-:4]);
								end
							end
						4'd7: begin
							r[0] = 1;
							r[75] = 1;
							r = r | op_rmw(o[17-:3]);
						end
						4'd8: begin
							r[0] = 1;
							r = r | rmw_out(o[17-:3], o[14-:5]);
						end
						default:
							;
					endcase
				5'd11:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_pc(0);
							r[75] = 1;
							r[53] = 1;
							r[44] = 1;
							r[71] = 1;
							r[40] = 1;
							r[33] = 1;
						end
						4'd4: begin
							r = addr_add_pch(0);
							r[39] = 1;
							r[36] = 1;
							r[70] = 1;
							r[42] = 1;
							if (!br_back) begin
								r[43] = 1;
								r[28] = 1;
							end
							else
								r[44] = 1;
							r[33] = 1;
						end
						default:
							;
					endcase
				5'd12:
					(* full_case, parallel_case *)
					case (n)
						4'd3: r = addr_pc(0) | alu_fix(1'b0);
						default:
							;
					endcase
				5'd13:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_pc(0);
							r[38] = 1;
							r[36] = 1;
							r[22] = 1;
							r = r | alu_fix(1'b0);
						end
						4'd4: begin
							r = addr_dl_add(0);
							r[62] = 1;
							r[61] = 1;
							r[44] = 1;
							r[41] = 1;
							r[33] = 1;
							r[28] = 1;
						end
						4'd5: begin
							r[60] = 1;
							r[35] = 1;
							r = r | alu_fix(1'b0);
						end
						default:
							;
					endcase
				5'd18:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_stack(0);
							r[0] = 1;
							r[46] = 1;
							if (ir[6])
								r[63] = 1;
							else begin
								r[59] = 1;
								r[1] = 1;
							end
						end
						default:
							;
					endcase
				5'd19:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_stack(0);
							r[47] = 1;
						end
						4'd4: r = addr_stack(0);
						default:
							;
					endcase
				5'd14:
					(* full_case, parallel_case *)
					case (n)
						4'd3: r = addr_stack(0) | alu_fix(1'b0);
						4'd4: begin
							r = addr_stack(0);
							r[0] = 1;
							r[46] = 1;
							r[70] = 1;
						end
						4'd5: begin
							r = addr_stack(0);
							r[0] = 1;
							r[46] = 1;
							r[72] = 1;
						end
						4'd6: begin
							r = addr_pc(0);
							r[38] = 1;
							r[36] = 1;
						end
						default:
							;
					endcase
				5'd16:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_stack(0);
							r[47] = 1;
						end
						4'd4: begin
							r = addr_stack(0);
							r[47] = 1;
						end
						4'd5: r = addr_stack(0) | alu_fix(1'b0);
						4'd6: begin
							r = addr_dl_add(0);
							r[39] = 1;
							r[37] = 1;
							r[22] = 1;
						end
						default:
							;
					endcase
				5'd17:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_stack(0);
							r[47] = 1;
						end
						4'd4: begin
							r = addr_stack(0);
							r[47] = 1;
						end
						4'd5: begin
							r = addr_stack(0);
							r[47] = 1;
							r[75] = 1;
							r[2] = 1;
							r[21] = 1;
							r[14] = 1;
							r[18] = 1;
						end
						4'd6: r = addr_stack(0) | alu_fix(1'b0);
						default:
							;
					endcase
				5'd15:
					(* full_case, parallel_case *)
					case (n)
						4'd3: begin
							r = addr_stack(0);
							r[0] = ~res_active;
							r[46] = 1;
							r[70] = 1;
						end
						4'd4: begin
							r = addr_stack(0);
							r[0] = ~res_active;
							r[46] = 1;
							r[72] = 1;
						end
						4'd5: begin
							r = addr_stack(0);
							r[0] = ~res_active;
							r[46] = 1;
							r[59] = 1;
							r[1] = ~int_active;
						end
						4'd6: begin
							r = addr_vector(1'b0);
							r[7] = 1;
						end
						4'd7: r = addr_vector(1'b1) | alu_fix(1'b0);
						default:
							;
					endcase
				default:
					;
			endcase
			seq = r;
		end
	endfunction
	reg br_flag;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (ir[7:6])
			2'b00: br_flag = p[7];
			2'b01: br_flag = p[6];
			2'b10: br_flag = p[0];
			default: br_flag = p[1];
		endcase
	end
	assign br_take = br_flag == ir[5];
	assign br_fix = dl[7] ^ acr_now;
	assign br_back = dl[7];
	reg wr_q;
	reg rdy_q;
	wire rdy_cy = (phi1_en ? rdy : rdy_q);
	assign hold = ~rdy_cy & ~wr_q;
	always @(posedge clk_sys)
		if (!res_n)
			rdy_q <= 1'b1;
		else if (phi1_en)
			rdy_q <= rdy;
	reg br_back_q;
	wire adh_carry;
	assign adh_carry = ~((d[24-:5] == 5'd11) & br_back_q);
	wire sh_write_cycle;
	assign sh_write_cycle = sh_store && ((((d[24-:5] == 5'd7) || (d[24-:5] == 5'd8)) && (t == 4'd5)) || ((d[24-:5] == 5'd10) && (t == 4'd6)));
	function automatic [75:0] hold_mask;
		input reg [75:0] x;
		input reg carry;
		reg [75:0] r;
		begin
			r = x;
			r[22] = 1'b0;
			r[35] = 1'b0;
			r[0] = 1'b0;
			r[2] = 1'b0;
			r[72] = 1'b0;
			r[41] = 1'b0;
			r[44] = 1'b0;
			r[43] = 1'b0;
			r[42] = 1'b0;
			r[40] = 1'b0;
			r[33] = 1'b0;
			r[32] = 1'b0;
			r[31] = 1'b0;
			r[30] = 1'b0;
			r[29] = 1'b0;
			r[28] = 1'b0;
			r[49] = 1'b0;
			r[47] = 1'b0;
			r[46] = 1'b0;
			r[34] = (x[34] & x[52]) & carry;
			r[25] = sh_write_cycle;
			hold_mask = r;
		end
	endfunction
	wire [75:0] c_pre;
	assign c_pre = (hold ? hold_mask(c_reg, adh_carry) : c_reg);
	reg so_edge_q;
	always @(*) begin
		if (_sv2v_0)
			;
		c = c_pre;
		c[10] = so_edge_q;
		c[0] = c_pre[0] & ~res_now;
	end
	wire so_edge;
	assign so_edge = so_last & ~so_n;
	function automatic is_last;
		input reg [3:0] k;
		input reg crossed;
		input reg taken;
		input reg pch_fix;
		reg r;
		begin
			r = 1'b0;
			if (k != 4'd1)
				(* full_case, parallel_case *)
				case (d[24-:5])
					5'd0, 5'd1, 5'd2: r = k == 4'd2;
					5'd20: r = 1'b0;
					5'd3: r = (d[19-:2] == 2'd2 ? k == 4'd5 : k == 4'd3);
					5'd4, 5'd5: r = (d[19-:2] == 2'd2 ? k == 4'd6 : k == 4'd4);
					5'd6: r = (d[19-:2] == 2'd2 ? k == 4'd6 : k == 4'd4);
					5'd7, 5'd8:
						(* full_case, parallel_case *)
						case (d[19-:2])
							2'd0: r = ((k == 4'd4) && !crossed) || (k == 4'd5);
							2'd1: r = k == 4'd5;
							default: r = k == 4'd7;
						endcase
					5'd9: r = (d[19-:2] == 2'd2 ? k == 4'd8 : k == 4'd6);
					5'd10:
						(* full_case, parallel_case *)
						case (d[19-:2])
							2'd0: r = ((k == 4'd5) && !crossed) || (k == 4'd6);
							2'd1: r = k == 4'd6;
							default: r = k == 4'd8;
						endcase
					5'd11: r = (((k == 4'd2) && !taken) | ((k == 4'd3) && !pch_fix)) | (k == 4'd4);
					5'd12: r = k == 4'd3;
					5'd13: r = k == 4'd5;
					5'd14: r = k == 4'd6;
					5'd16, 5'd17: r = k == 4'd6;
					5'd15: r = k == 4'd7;
					5'd18: r = k == 4'd3;
					5'd19: r = k == 4'd4;
					default:
						;
				endcase
			is_last = r;
		end
	endfunction
	wire last;
	assign last = is_last(t, pgx, br_take, br_fix);
	reg [5:0] tg_c2;
	reg sync_c2;
	wire tz_pre_n;
	assign tz_pre_n = ~pd_two_cycle;
	wire end_x;
	assign end_x = (t != 4'd1) & (d[24-:5] == 5'd11 ? (t == 4'd3) & tg[3] : is_last(t + 4'd1, ((t == 4'd3) || (t == 4'd4) ? acr_now : pgx), br_take, br_fix) & ~pd_two_cycle);
	reg [3:0] rmw_rd;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (d[24-:5])
			5'd3: rmw_rd = 4'd3;
			5'd4, 5'd5, 5'd6: rmw_rd = 4'd4;
			5'd7, 5'd8: rmw_rd = 4'd5;
			5'd9, 5'd10: rmw_rd = 4'd6;
			default: rmw_rd = 4'd0;
		endcase
	end
	reg ext_t5_r;
	reg ext_t6_r;
	assign ext_t5 = (hold ? ext_t5_r : (d[19-:2] == 2'd2) && (t == rmw_rd));
	assign ext_t6 = (hold ? ext_t6_r : (d[19-:2] == 2'd2) && (t == (rmw_rd + 4'd1)));
	wire tg_go;
	assign t_zero = (sync | (end_x_q & tg_go)) | res_p;
	assign tg_go = ~hold;
	always @(*) begin
		if (_sv2v_0)
			;
		tg[0] = ~(sync | (~t_zero & tz_pre_n)) | (tg_c2[0] & ~tg_go);
		tg[1] = tg_c2[0] & tg_go;
		tg[2] = ~t_zero & ((tg_c2[2] & ~tg_go) | (sync_c2 & tg_go));
		tg[3] = ~t_zero & ((tg_c2[3] & ~tg_go) | (tg_c2[2] & tg_go));
		tg[4] = ~t_zero & ((tg_c2[4] & ~tg_go) | (tg_c2[3] & tg_go));
		tg[5] = ~t_zero & ((tg_c2[5] & ~tg_go) | (tg_c2[4] & tg_go));
	end
	assign nt = (last | tg[0] ? 4'd1 : (jammed && (t >= 4'd6) ? t : t + 4'd1));
	reg n_int_g;
	wire n_res_g;
	wire vec_merge;
	always @(nt or nt or jammed or idx_cross_q or nt or d or res_now or nmi_pending or res_now or res_now or nmi_pending or res_now or int_active or res_active or res_active or res_active or ir[6] or br_back or p[0] or p[0] or sh_store or acr_now or sh_store or p[0] or p[0] or p[0] or p[0] or sh_store or acr_now or sh_store or p[0] or p[0] or p[0] or p[0] or p[0] or p[0] or d or p[0] or p[3] or p[3] or p[3] or nc or int_active or pd_implied or nt or d or ir[6] or p[0] or p[3] or p[0] or p[3] or p[0] or p[3] or p[3] or p[0] or p[3] or p[0] or nc or n_res_g or n_int_g or res_now or nmi_pending or res_now or vec_merge or n_pc_src or n_pc_src or n_pc_src or n_pc_src or nt or _sv2v_0) begin
		if (_sv2v_0)
			;
		nc = mos6502_pkg_CTL_IDLE;
		if (nt == 4'd1) begin
			(* full_case, parallel_case *)
			case (n_pc_src)
				2'd1: nc = addr_dl_add(0);
				2'd2: nc = addr_add_pch(0);
				2'd3: nc = addr_fix_hi(0);
				default: nc = addr_pc(0);
			endcase
			if (n_pc_src == 2'd3) begin
				nc[38] = 1;
				nc[37] = 1;
			end
			else if (n_pc_src == 2'd0) begin
				nc[38] = 1;
				nc[36] = 1;
			end
			else begin
				nc[39] = 1;
				if (n_pc_src == 2'd2)
					nc[36] = 1;
				else
					nc[37] = 1;
			end
			if (vec_merge) begin
				nc = addr_vector(1'b1);
				nc[73] = 1'b1;
				nc[39] = 1'b1;
				nc[37] = 1'b1;
			end
			nc[22] = ~(n_int_g | n_res_g);
			nc = nc | op_a(d);
		end
		else if (nt == 4'd2) begin
			nc = addr_pc(0);
			nc[38] = 1;
			nc[36] = 1;
			nc[22] = ~pd_implied & ~int_active;
			nc = nc | op_b(d);
		end
		else
			nc = seq(d, nt, idx_cross_q);
		if (jammed) begin
			nc = mos6502_pkg_CTL_IDLE;
			nc[35] = 1'b1;
			nc[34] = 1'b1;
			nc[58] = (nt == 4'd4) || (nt == 4'd5);
		end
	end
	reg irq_p;
	reg nmi_p;
	reg nmi_l;
	wire nmig;
	reg nmig_c2;
	reg vec_n_c2;
	reg brk_done_q;
	wire brk_done;
	assign n_res_g = res_c2 | (res_g & ~brk_done);
	reg sync_short;
	assign res_no_prefetch = res_p & ~sync_short;
	assign vec_merge = (tg[0] && (d[24-:5] == 5'd15)) && (t == 4'd6);
	wire vec_cyc;
	assign vec_cyc = (d[24-:5] == 5'd15) && ((t == 4'd6) || (t == 4'd7));
	assign brk_done = ((d[24-:5] == 5'd15) && (t == 4'd6)) && !hold;
	wire nmi_req;
	assign nmi_req = (nmi_p & ~nmi_l) & vec_n_c2;
	assign nmig = nmi_req | (nmig_c2 & ~brk_done_q);
	always @(posedge clk_sys) begin
		if (phi1_en) begin
			irq_p <= ~irq_n;
			nmi_p <= ~nmi_n;
			nmi_l <= ~nmi_n & (nmig_c2 | nmi_l);
			nmig_c2 <= nmig;
			res_c2 <= ~res_n;
			res_g <= res_c2 | (res_g & ~brk_done_q);
			vec_n_c2 <= ~vec_cyc;
		end
		if (phi2_en) begin
			res_p <= res_c2;
			sync_short <= (((d[24-:5] == 5'd11) && (t == 4'd3)) && last) && tg[3];
			brk_done_q <= brk_done;
			tg_c2 <= tg;
			sync_c2 <= sync;
			if (!hold) begin
				end_x_q <= end_x;
				ext_t5_r <= ext_t5;
				ext_t6_r <= ext_t6;
			end
		end
	end
	wire int_req;
	wire poll_now;
	assign nmi_pending = nmig;
	assign int_req = nmi_pending || (irq_p && !p[2]);
	assign poll_now = (d[24-:5] == 5'd11 ? (t == 4'd2) || (t == 4'd4) : last);
	assign take_int = ((last && !int_active) && (d[24-:5] != 5'd15)) && (poll_now ? int_req : int_armed);
	always @(*) begin
		if (_sv2v_0)
			;
		n_int_g = int_g;
		if ((d[24-:5] == 5'd15) && (t == 4'd7))
			n_int_g = 1'b0;
		else if (take_int)
			n_int_g = 1'b1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		n_pc_src = 2'd0;
		if (last)
			(* full_case, parallel_case *)
			case (d[24-:5])
				5'd12, 5'd13, 5'd15, 5'd14, 5'd17: n_pc_src = 2'd1;
				5'd11: n_pc_src = (t == 4'd2 ? 2'd0 : (t == 4'd3 ? 2'd2 : 2'd3));
				default: n_pc_src = 2'd0;
			endcase
	end
	always @(posedge clk_sys)
		if (phi2_en) begin
			so_last <= so_n;
			so_edge_q <= so_edge;
			wr_q <= c[0];
			if (!hold)
				sync_q <= t == 4'd1;
			if (hold) begin
				t <= t;
				c_reg <= c_reg;
				if (((t == 4'd1) && !int_active) && int_req) begin
					int_g <= 1'b1;
					int_armed <= 1'b0;
					c_reg[22] <= 1'b0;
				end
				if (sh_write_cycle)
					c_reg[34] <= 1'b0;
			end
			else begin
				t <= nt;
				c_reg <= nc;
				if ((d[24-:5] == 5'd11) && (t == 4'd3))
					br_back_q <= br_back;
				int_g <= n_int_g;
				if (poll_now)
					int_armed <= int_req;
				if (take_int)
					int_armed <= 1'b0;
				if (t == 4'd1)
					ir <= (int_active ? 8'h00 : data_in);
				if ((t == 4'd3) || (t == 4'd4))
					pgx <= acr_now;
				if (((d[24-:5] == 5'd7) || (d[24-:5] == 5'd8)) && (t == 4'd3))
					idx_cross_q <= acr_now;
				if ((d[24-:5] == 5'd10) && (t == 4'd4))
					idx_cross_q <= acr_now;
			end
		end
	initial _sv2v_0 = 0;
endmodule
