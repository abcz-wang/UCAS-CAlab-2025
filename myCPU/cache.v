
module cache(
    input wire        clk,
    input wire        resetn,

    // Cache 模块与 CPU 流水线的交互接口
    input wire        valid,  // 表明请求有效
    input wire        op,     // 1：WRITE。0：READ
    input wire [ 7:0] index,  // 地址的 index 域（addr[11:4]）虚地址
    input wire [19:0] tag,    // 经虚实地址转换后的 paddr 形成的 tag，由于来自组合逻辑运算，故与 index 是同拍信号
    input wire [ 3:0] offset, // 地址的 offset 域（addr[3:0]）虚地址
    input wire [ 3:0] wstrb,  // 写字节使能信号
    input wire [31:0] wdata,  // 写数据
    
    output wire        addr_ok, // 该次请求的地址传输 OK。读：地址被接收。写：地址和数据被接收
    output wire        data_ok, // 该次请求的数据传输 OK。读：数据返回。写：数据写入完成
    output wire [31:0] rdata,   // 读 Cache 的结果

    // Cache 模块与 AXI 总线的交互接口
    output wire        rd_req,   // 读请求有效信号。高电平有效
    output wire [ 2:0] rd_type,  // 读请求类型。3'b000字节，3'b001半字，3'b010字，3'b100Cache行
    output wire [31:0] rd_addr,  // 读请求起始地址

    input  wire        rd_rdy,   // 读请求能否被接收的握手信号。高电平有效
    input  wire        ret_valid,// 返回数据有效信号。高电平有效
    input  wire        ret_last, // 返回数据是一次读请求对应的最后一个返回数据
    input  wire [31:0] ret_data, // 读返回数据

    output wire        wr_req,   // 写请求有效信号。高电平有效
    output wire [ 2:0] wr_type,  // 写请求类型。3'b000字节，3'b001半字，3'b010字，3'b100Cache 行
    output wire [31:0] wr_addr,  // 写请求起始地址
    output wire [ 3:0] wr_wstrb,  // 写操作的字节掩码。仅在写请求类型为 3'b000、3'b001、3'b010 情况下才有意义
    output wire [127:0] wr_data, // 写数据
	input wire  [ 1:0] datm,
    input  wire        wr_rdy /*写请求能否被接收的握手信号。高电平有效。此处要求 wr_rdy 要先于 wr_req
置起，wr_req 看到 wr_rdy 后才可能置上。所以 wr_rdy 的生成不要组合逻辑依赖
wr_req，它应该是当 AXI 总线接口内部的 16 字节写缓存为空时就置上*/
);
localparam READ = 1'b0;
localparam WRITE = 1'b1;
//cache访问类型
wire lookup,hitwrite,replace,refill;

wire reset;
assign reset = ~resetn;

reg [1:0] datm_reg;
always @(posedge clk)begin
    if(reset)
        datm_reg <= 2'b01;
    else if(lookup)
        datm_reg <= datm;
end
wire uncache;
assign uncache = datm_reg == 2'b00;
//RAM相关接口
wire [7:0]data_addr;
wire [31:0]data_wdata;
wire [31:0]data_w0b0_rdata,data_w0b1_rdata, data_w0b2_rdata, data_w0b3_rdata, 
		data_w1b0_rdata, data_w1b1_rdata, data_w1b2_rdata, data_w1b3_rdata;
wire data_w0b0_en, data_w0b1_en, data_w0b2_en, data_w0b3_en,
	data_w1b0_en, data_w1b1_en, data_w1b2_en, data_w1b3_en;
wire [ 3:0] data_w0b0_we, data_w0b1_we, data_w0b2_we, data_w0b3_we,
		data_w1b0_we, data_w1b1_we, data_w1b2_we, data_w1b3_we;

wire [7:0]tagv_addr;
wire [20:0]tagv_wdata;
wire [20:0] tagv_w0_rdata, tagv_w1_rdata;
wire tagv_w0_en, tagv_w1_en;
wire tagv_w0_we, tagv_w1_we;

data_bank_ram data_way0bank0 (
  .clka(clk),    // input wire clka
    .ena(data_w0b0_en),      // input wire ena
  .wea(data_w0b0_we & {4{~uncache}}),       // input wire [3 : 0] wea，字节写使能信号
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w0b0_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way0bank1 (
  .clka(clk),    // input wire clka
    .ena(data_w0b1_en),      // input wire ena
  .wea(data_w0b1_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w0b1_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way0bank2 (
  .clka(clk),    // input wire clka
    .ena(data_w0b2_en),      // input wire ena
  .wea(data_w0b2_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w0b2_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way0bank3 (
  .clka(clk),    // input wire clka
    .ena(data_w0b3_en),      // input wire ena
  .wea(data_w0b3_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w0b3_rdata)  // output wire [31 : 0] douta
);

data_bank_ram data_way1bank0 (
  .clka(clk),    // input wire clka
  .ena(data_w1b0_en),      // input wire ena
  .wea(data_w1b0_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w1b0_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way1bank1 (
  .clka(clk),    // input wire clka
  .ena(data_w1b1_en),      // input wire ena
  .wea(data_w1b1_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w1b1_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way1bank2 (
  .clka(clk),    // input wire clka
  .ena(data_w1b2_en),      // input wire ena
  .wea(data_w1b2_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w1b2_rdata)  // output wire [31 : 0] douta
);
data_bank_ram data_way1bank3 (
  .clka(clk),    // input wire clka
  .ena(data_w1b3_en),      // input wire ena
  .wea(data_w1b3_we & {4{~uncache}}),      // input wire [3 : 0] wea
  .addra(data_addr),  // input wire [7 : 0] addra
  .dina(data_wdata),    // input wire [31 : 0] dina
  .douta(data_w1b3_rdata)  // output wire [31 : 0] douta
);

tagv_ram tagv_way0 (
  .clka(clk),    // input wire clka
  .ena(tagv_w0_en),      // input wire ena
  .wea(tagv_w0_we & ~uncache),      // input wire [0 : 0] wea
  .addra(tagv_addr),  // input wire [7 : 0] addra
  .dina(tagv_wdata),    // input wire [20 : 0] dina
  .douta(tagv_w0_rdata)  // output wire [20 : 0] douta
);
tagv_ram tagv_way1 (
  .clka(clk),    // input wire clka
    .ena(tagv_w1_en),      // input wire ena
  .wea(tagv_w1_we & ~uncache),      // input wire [0 : 0] wea
  .addra(tagv_addr),  // input wire [7 : 0] addra
  .dina(tagv_wdata),    // input wire [20 : 0] dina
  .douta(tagv_w1_rdata)  // output wire [20 : 0] douta
);
//dirty位放在regfile中
reg [255:0] dirty_way0;
reg [255:0] dirty_way1;
//Request buffer
reg 	reg_op;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;

//Miss buffer
reg 	miss_replace_way; // 0: way0, 1: way1
reg [1:0] miss_ret_cnt; // 从AXI总线返回了几个32位数据

//Write buffer
reg        wb_valid;
reg        wb_way;        // 写哪一路
reg [7:0]  wb_index;      // 写哪一组
reg [1:0]  wb_bank;       // 写哪一个 bank
reg [3:0]  wb_wstrb;      // 字节写使能
reg [31:0] wb_wdata;      // 写数据
//Tag compare
wire        way0_v, way1_v;
wire [19:0] way0_tag, way1_tag;
wire        way0_hit, way1_hit;
wire        cache_hit;
wire hit_write,hit_read;
wire way0_hit_eff, way1_hit_eff;
assign {way0_tag, way0_v} = tagv_w0_rdata;
assign {way1_tag, way1_v} = tagv_w1_rdata;
assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag); 
assign way0_hit_eff = way0_hit & ~uncache;
assign way1_hit_eff = way1_hit & ~uncache;
assign cache_hit = (way0_hit_eff || way1_hit_eff);
assign hit_write = cache_hit && (reg_op == WRITE) && (M_current_state == M_LOOKUP);
assign hit_read = cache_hit && (reg_op == READ) && (M_current_state == M_LOOKUP);

//Date select
wire [127:0] way0_data, way1_data;
wire [31:0] way0_load_word, way1_load_word, load_res;
assign way0_data = {data_w0b3_rdata, data_w0b2_rdata, data_w0b1_rdata, data_w0b0_rdata};
assign way1_data = {data_w1b3_rdata, data_w1b2_rdata, data_w1b1_rdata, data_w1b0_rdata};
assign way0_load_word = way0_data[reg_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[reg_offset[3:2]*32 +: 32];

assign load_res = {32{way0_hit_eff}} & way0_load_word
				| {32{way1_hit_eff}} & way1_load_word
				| {32{M_current_state == M_REFILL && ret_valid}} & ret_data;//从AXI总线返回的数据
//LFSR
reg [3:0] lfsr;
wire replace_way;
wire [127:0] replace_data;
wire feedback = lfsr[3] ^ lfsr[2];
always @(posedge clk) begin
    if (!resetn) begin
        lfsr <= 4'b0001; 
    end else if(ret_valid && ret_last) begin
        lfsr <= {lfsr[2:0], feedback};
    end
end

reg uncache_no_req;
always @(posedge clk) begin
    if (reset) begin
        uncache_no_req <= 1'b0;
    end else if ((M_current_state == M_MISS) && uncache && (reg_op == WRITE) && wr_rdy) begin
        uncache_no_req <= 1'b1;
    end else if (uncache_no_req && wr_rdy) begin
        uncache_no_req <= 1'b0;
    end
end

assign replace_way = lfsr[0];
assign replace_data = replace_way ? way1_data : way0_data;

wire replace_dirty;
assign replace_dirty = replace_way ? (dirty_way1[reg_index] && way1_v) : (dirty_way0[reg_index] && way0_v);
//情况1，LOOKUP，store命中cache，不使用命中信息，视为命中,阻塞处理
//这里不使用cache_hit信号，也是因为cache_hit信号需要靠从ram中读出的数据生成的
//这个判断hit write也会连到ram使能端，从而输出依赖输入，产生逻辑环
wire hit_write_hazard_lookup = (M_current_state == M_LOOKUP) && (reg_op == WRITE) && valid && (op == READ) && {tag,index,offset[3:2]} == {reg_tag,reg_index,reg_offset[3:2]};//��ַ��ͬ
//情况2，WB_WRITE阶段，读写同一个 bank 则必须阻塞
wire hit_write_hazard_wb = (WB_current_state == WB_WRITE) && (op == READ) && valid && (offset[3:2] == wb_bank);//��дͬһ�� bank ���������
wire have_hazard = hit_write_hazard_lookup || hit_write_hazard_wb;
// 主状态机
localparam M_IDLE    = 5'b00001,
           M_LOOKUP  = 5'b00010,
           M_MISS    = 5'b00100,
           M_REPLACE = 5'b01000,
           M_REFILL  = 5'b10000;

reg [4:0] M_current_state;
reg [4:0] M_next_state;

//Write Buffer状态机
localparam 	WB_IDLE = 2'b01,
			WB_WRITE = 2'b10;
reg [1:0] WB_current_state;
reg [1:0] WB_next_state;
//状态机跳转
always @(posedge clk ) 
begin
	if (reset)begin
		M_current_state <= M_IDLE;
	end
	else begin
		M_current_state <= M_next_state;
	end
end

always @(posedge clk ) 
begin
	if (reset)begin
		WB_current_state <= WB_IDLE;
	end
	else begin
		WB_current_state <= WB_next_state;
	end
end
//状态机组合逻辑
always @(*) begin
	case (M_current_state)
		M_IDLE: begin
			if (valid && !hit_write_hazard_wb && ~uncache_no_req) begin
				M_next_state = M_LOOKUP;
			end
			else begin
				M_next_state = M_IDLE;
			end
		end
		M_LOOKUP: begin
			if (~cache_hit || uncache) begin
				M_next_state = M_MISS;
			end
			else if (!valid || have_hazard) begin
				M_next_state = M_IDLE;
			end
			else begin
				M_next_state = M_LOOKUP;
			end
		end
		M_MISS: begin
			if (uncache && reg_op == WRITE) begin
				if (wr_rdy) M_next_state = M_IDLE;
				else        M_next_state = M_MISS;
			end
			else begin
				if (wr_rdy || !replace_dirty)
					M_next_state = M_REPLACE;
				else
					M_next_state = M_MISS;
			end
		end
		M_REPLACE: begin
			if (rd_rdy) begin
				M_next_state = M_REFILL;
			end
			else begin
				M_next_state = M_REPLACE;
			end
		end
		M_REFILL: begin
			if (ret_valid && ret_last) begin
				M_next_state = M_IDLE;
			end
			else begin
				M_next_state = M_REFILL;
			end
		end
		default: M_next_state = M_IDLE;
	endcase
end
always @(*) begin
	case (WB_current_state)
		WB_IDLE: begin
			if (hit_write) begin
				WB_next_state = WB_WRITE;
			end
			else begin
				WB_next_state = WB_IDLE;
			end
		end
		WB_WRITE: begin
			if (hit_write) begin
				WB_next_state = WB_WRITE;
			end
			else begin
				WB_next_state = WB_IDLE;
			end
		end
		default: WB_next_state = WB_IDLE;
	endcase
end
//TAGV
assign tagv_addr = {8{lookup_hit}} & index
				| {8{replace | refill}} & reg_index;

assign tagv_wdata =  {reg_tag, 1'b1};
assign tagv_w0_we = (refill) && (replace_way == 1'b0) && ret_valid && (miss_ret_cnt == reg_offset[3:2]);
assign tagv_w1_we = (refill) && (replace_way == 1'b1) && ret_valid && (miss_ret_cnt == reg_offset[3:2]);
assign tagv_w0_en = lookup_hit | (replace && replace_way == 1'b0) | (refill && replace_way == 1'b0);
assign tagv_w1_en = lookup_hit | (replace && replace_way == 1'b1) | (refill && replace_way == 1'b1);
//数据通路部分
assign lookup = ~uncache_no_req && ((M_current_state == M_LOOKUP) && cache_hit & valid & !hit_write_hazard_wb || 
				(M_current_state == M_IDLE) && valid && !have_hazard);
assign hitwrite = (WB_current_state == WB_WRITE);
assign replace = (M_current_state == M_REPLACE || M_current_state == M_MISS);
assign refill = (M_current_state == M_REFILL);
/*不使用命中信息cache_hit控制RAM读使能,视为命中.如果使用cache_hit信号
因为cache_hit信号需要靠从ram中读出的数据生成的，因此使用这个信号
会让RAM读使能依赖输出信号，从而引入逻辑环，产生错误*/
wire lookup_hit = ~uncache_no_req && ((M_current_state == M_LOOKUP) & valid & !hit_write_hazard_wb || 
				(M_current_state == M_IDLE) && valid && !have_hazard);
//地址
assign data_addr = {8{lookup_hit}} & index
				| {8{replace | refill}} & reg_index
				| {8{hitwrite}} & wb_index;
//字节写使能
assign  data_w0b0_we = {4{(hitwrite && (wb_way == 1'b0) && (wb_bank == 2'b00))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b00) && (replace_way == 1'b0) && ret_valid)}} & {4{1'b1}};//д��way0bank0
assign  data_w0b1_we = {4{(hitwrite && (wb_way == 1'b0) && (wb_bank == 2'b01))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b01) && (replace_way == 1'b0) && ret_valid)}} & {4{1'b1}};//д��way0bank1
assign  data_w0b2_we = {4{(hitwrite && (wb_way == 1'b0) && (wb_bank == 2'b10))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b10) && (replace_way == 1'b0) && ret_valid)}} & {4{1'b1}};//д��way0bank2
assign  data_w0b3_we = {4{(hitwrite && (wb_way == 1'b0) && (wb_bank == 2'b11))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b11) && (replace_way == 1'b0) && ret_valid)}} & {4{1'b1}};//д��way0bank3

assign  data_w1b0_we = {4{(hitwrite && (wb_way == 1'b1) && (wb_bank == 2'b00))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b00) && (replace_way == 1'b1) && ret_valid)}} & {4{1'b1}};//д��way1bank0
assign data_w1b1_we = {4{(hitwrite && (wb_way == 1'b1) && (wb_bank == 2'b01))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b01) && (replace_way == 1'b1) && ret_valid)}} & {4{1'b1}};//д��way1bank1
assign data_w1b2_we = {4{(hitwrite && (wb_way == 1'b1) && (wb_bank == 2'b10))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b10) && (replace_way == 1'b1) && ret_valid)}} & {4{1'b1}};//д��way1bank2
assign data_w1b3_we = {4{(hitwrite && (wb_way == 1'b1) && (wb_bank == 2'b11))}} & wb_wstrb
						|{4{(refill && (miss_ret_cnt == 2'b11) && (replace_way == 1'b1) && ret_valid)}} & {4{1'b1}};//д��way1bank3
//写数据
wire [31:0] merge_word;
assign merge_word[31:24] = reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24];
assign merge_word[23:16] = reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16];
assign merge_word[15: 8] = reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8];
assign merge_word[ 7: 0] = reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0];
wire is_target_word;
assign is_target_word = (miss_ret_cnt == reg_offset[3:2]);
wire [31:0] refill_ram_wdata;
assign refill_ram_wdata = (is_target_word && reg_op == WRITE) ? merge_word : ret_data;

assign data_wdata = {32{hitwrite}} & wb_wdata
						| {32{refill}} & refill_ram_wdata;
//片选
assign data_w0b0_en = (lookup_hit && offset[3:2] == 2'b00) | (hitwrite && (wb_way == 1'b0)) | (replace && (replace_way == 1'b0)) | (refill && (replace_way == 1'b0));
assign data_w0b1_en = (lookup_hit && offset[3:2] == 2'b01) | (hitwrite && (wb_way == 1'b0)) | (replace && (replace_way == 1'b0)) | (refill && (replace_way == 1'b0));
assign data_w0b2_en = (lookup_hit && offset[3:2] == 2'b10) | (hitwrite && (wb_way == 1'b0)) | (replace && (replace_way == 1'b0)) | (refill && (replace_way == 1'b0));
assign data_w0b3_en = (lookup_hit && offset[3:2] == 2'b11) | (hitwrite && (wb_way == 1'b0)) | (replace && (replace_way == 1'b0)) | (refill && (replace_way == 1'b0));
assign data_w1b0_en = (lookup_hit && offset[3:2] == 2'b00) | (hitwrite && (wb_way == 1'b1)) | (replace && (replace_way == 1'b1)) | (refill && (replace_way == 1'b1));
assign data_w1b1_en = (lookup_hit && offset[3:2] == 2'b01) | (hitwrite && (wb_way == 1'b1)) | (replace && (replace_way == 1'b1)) | (refill && (replace_way == 1'b1));
assign data_w1b2_en = (lookup_hit && offset[3:2] == 2'b10) | (hitwrite && (wb_way == 1'b1)) | (replace && (replace_way == 1'b1)) | (refill && (replace_way == 1'b1));
assign data_w1b3_en = (lookup_hit && offset[3:2] == 2'b11) | (hitwrite && (wb_way == 1'b1)) | (replace && (replace_way == 1'b1)) | (refill && (replace_way == 1'b1));
//request buffer
always @(posedge clk ) 
begin
	if(reset)begin
		reg_op	 <= 1'b0;
		reg_index <= 8'b0;
		reg_tag	 <= 20'b0;
		reg_offset<= 4'b0;
		reg_wstrb <= 4'b0;	
		reg_wdata <= 32'b0;
	end
	else if(lookup)begin
		reg_op	 <= op;
		reg_index <= index;
		reg_tag	 <= tag;
		reg_offset<= offset;
		reg_wstrb <= wstrb;	
		reg_wdata <= wdata;
	end
end

//miss buffer
always @(posedge clk ) 
begin
	if(reset)begin
		miss_ret_cnt <= 2'b0;
	end
	else if(refill && ret_valid && ~uncache)begin
		miss_ret_cnt <= miss_ret_cnt + 1'b1;
	end
end
//write buffer
always @(posedge clk ) begin
	if(reset) begin
		wb_valid <= 1'b0;
		wb_way   <= 1'b0;
		wb_index <= 8'b0;
		wb_bank  <= 2'b0;
		wb_wstrb <= 4'b0;
		wb_wdata <= 32'b0;
	end
	else if (hit_write) begin
		wb_valid <= 1'b1;
		wb_way   <= way0_hit ? 1'b0 : 1'b1;
		wb_index <= reg_index;
		wb_bank  <= reg_offset[3:2];
		wb_wstrb <= reg_wstrb;
		wb_wdata <= reg_wdata;
	end
	else begin
		wb_valid <= 1'b0;
	end
end
//dirty位更新
always @(posedge clk ) 
begin
	if (reset)begin
		dirty_way0 <= 256'b0;
		dirty_way1 <= 256'b0;
	end
	else if(hitwrite && ~uncache)begin
		if(wb_way == 1'b0) begin
			dirty_way0[wb_index] <= 1'b1;
		end
		else begin
			dirty_way1[wb_index] <= 1'b1;
		end
	end
	else if(refill && ~uncache)begin
		if(replace_way == 1'b0) begin
			dirty_way0[reg_index] <= 1'b0;
		end
		else begin
			dirty_way1[reg_index] <= 1'b0;
		end
	end
end
//cache - cpu 接口信号
assign addr_ok = ~uncache_no_req && ((M_current_state == M_IDLE) || (M_current_state == M_LOOKUP 
				&& valid && (cache_hit || uncache) && !have_hazard));

assign data_ok = (M_current_state == M_LOOKUP) && (cache_hit) && ~uncache ||
                 (M_current_state == M_MISS) && uncache && wr_rdy && reg_op == WRITE ||
                 (M_current_state == M_REFILL) && uncache && ret_valid && ret_last || 
                 (M_current_state == M_REFILL) && ~uncache && ret_valid && (miss_ret_cnt == reg_offset[3:2]);
assign rdata = load_res;
//cache - axi 接口信号
assign rd_req = (M_current_state == M_REPLACE);
assign rd_type = uncache ? 3'b010 : 3'b100;
assign rd_addr = uncache
               ? {reg_tag, reg_index, reg_offset}   
               : {reg_tag, reg_index, 4'b0000};     
assign wr_req = (M_current_state == M_MISS) && (replace_dirty) && ~uncache
             || (M_current_state == M_MISS) && (reg_op == WRITE)   &&  uncache;
assign wr_type = reg_op ? (
                    uncache ? (
                        (reg_wstrb == 4'b1111) ? 3'b010 :
                        ((reg_wstrb == 4'b0011) || (reg_wstrb == 4'b1100)) ? 3'b001 :
                        3'b000
                    ) : 3'b100
                ) : 3'b010;
assign wr_addr = uncache
               ? {reg_tag, reg_index, reg_offset}
               : { (replace_way ? way1_tag : way0_tag), reg_index, 4'b0000 };
assign wr_wstrb = {4{ uncache}} & reg_wstrb
                | {4{~uncache}} &4'b1111;
assign wr_data = uncache ? {96'b0, reg_wdata} : replace_data;

endmodule