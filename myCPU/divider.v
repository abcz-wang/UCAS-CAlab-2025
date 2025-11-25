module divider (
	input wire clk,
	input wire rst,
	input wire [31:0]src1,
	input wire [31:0]src2,
	input wire is_div_mod_s, 
	input wire is_div_mod_u,
	input wire div_or_mod, //若为除法，置为1，否则为mod,置为0
	input wire valid,
	output wire [31:0]div_result,
	output wire div_done
);
	wire [3:0]div_op;
	assign div_op[0] = is_div_mod_s&&div_or_mod;
	assign div_op[1] = is_div_mod_s&&!div_or_mod;
	assign div_op[2] = is_div_mod_u&&div_or_mod;
	assign div_op[3] = is_div_mod_u&&!div_or_mod;
	parameter INIT = 4'b0001;
	parameter WAIT = 4'b0010;
	parameter RUN = 4'b0100;
	parameter DONE = 4'b1000;

	wire        signed_divisor_tvalid;
    wire        signed_divisor_tready;
    wire        signed_dividend_tvalid;
    wire        signed_dividend_tready;
    wire        signed_dout_tvalid;

    wire        unsigned_divisor_tvalid;
    wire        unsigned_divisor_tready;
    wire        unsigned_dividend_tvalid;
    wire        unsigned_dividend_tready;
    wire        unsigned_dout_tvalid;  
wire [63:0]s_res,u_res;

reg [3:0]u_current_state;
reg [3:0]u_next_state;
reg [3:0]s_current_state;
reg [3:0]s_next_state;

always @(posedge clk ) begin
	if(rst)begin
		u_current_state <= INIT;
		s_current_state <= INIT;
	end
	else begin
		u_current_state <= u_next_state;
		s_current_state <= s_next_state;
	end
end
always @(*) begin
	case (s_current_state)
		INIT:begin
			s_next_state = WAIT;
		end
		WAIT:begin
			if(is_div_mod_s && signed_divisor_tready && signed_dividend_tready) begin
				s_next_state = RUN;
			end
			else begin
				s_next_state = WAIT;
			end
		end
		RUN:begin
			if(signed_dout_tvalid)begin
				s_next_state = DONE;
			end
			else begin
				s_next_state = RUN;
			end
			
		end
		DONE:begin
			if(valid)
				s_next_state = WAIT;
			else
				s_next_state = DONE;
		end
		default: s_next_state = INIT;
	endcase
end
assign signed_divisor_tvalid = (s_current_state == WAIT) && is_div_mod_s;
assign signed_dividend_tvalid = (s_current_state == WAIT) && is_div_mod_s;

mydiv my_s_div(
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(signed_divisor_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(signed_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(src2),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(signed_dividend_tvalid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(signed_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(src1),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(signed_dout_tvalid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(s_res)            // output wire [63 : 0] m_axis_dout_tdata
);

always @(*) begin
	case (u_current_state)
		INIT:begin
			u_next_state = WAIT;
		end
		WAIT:begin
			if(is_div_mod_u && unsigned_divisor_tready && unsigned_dividend_tready) begin
				u_next_state = RUN;
			end
			else begin
				u_next_state = WAIT;
			end
		end
		RUN:begin
			if(unsigned_dout_tvalid)begin
				u_next_state = DONE;
			end
			else begin
				u_next_state = RUN;
			end
			
		end
		DONE:begin
			u_next_state = WAIT;
		end
		default: u_next_state <= INIT;
	endcase
end
assign unsigned_divisor_tvalid = (u_current_state == WAIT) && is_div_mod_u;
assign unsigned_dividend_tvalid = (u_current_state == WAIT) && is_div_mod_u;

myudiv my_u_div(
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(unsigned_divisor_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(unsigned_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(src2),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(unsigned_dividend_tvalid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(unsigned_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(src1),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(unsigned_dout_tvalid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(u_res)            // output wire [63 : 0] m_axis_dout_tdata
);
assign div_result = {32 {div_op[0]} } & s_res[63:32] | //div_s
					{32 {div_op[1]} } & s_res[31:0]  | //mod_s
					{32 {div_op[2]} } & u_res[63:32] | //div_u
					{32 {div_op[3]} } & u_res[31:0];   //mod_u

assign div_done = is_div_mod_s & (s_current_state[3]) | is_div_mod_u & u_current_state[3];


endmodule