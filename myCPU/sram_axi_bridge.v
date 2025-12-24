
module sram_axi_bridge(
    input    wire           aclk,
    input    wire           aresetn,
    // read req channel
    output  reg [ 3:0]      arid,
    output  wire [31:0]      araddr,
    output  wire [ 7:0]      arlen,
    output  wire [ 2:0]      arsize,
    output  wire [ 1:0]      arburst,
    output  wire [ 1:0]      arlock,
    output  wire [ 3:0]      arcache,
    output  wire [ 2:0]      arprot,
    output   wire           	arvalid,
    input    wire           	arready,
    // read response channel
    input   wire	[ 3:0]      rid,
    input   wire	[31:0]      rdata,
    input   wire	[ 1:0]      rresp,
    input    wire           	rlast,
    input    wire           	rvalid,
    output   wire           	rready,
    // write req channel
    output  wire [ 3:0]      awid,
    output  wire [31:0]      awaddr,
    output  wire [ 7:0]      awlen,
    output  reg [ 2:0]      awsize,
    output  wire [ 1:0]      awburst,
    output  wire [ 1:0]      awlock,
    output  wire [ 3:0]      awcache,
    output  wire [ 2:0]      awprot,
    output   wire           	awvalid,
    input    wire           	awready,
    // write data channel
    output  wire [ 3:0]      wid,
    output  wire [31:0]      wdata,
    output  wire [ 3:0]      wstrb,
    output  wire         	wlast,
    output   wire           	wvalid,
    input     wire          	wready,
    // write response channel
    input   wire	[ 3:0]      bid,
    input   wire	[ 1:0]      bresp,
    input      wire         	bvalid,
    output    wire          	bready,
    // inst sram interface
    // icache rd interface
    input  wire             	icache_rd_req,
    input  wire 	[ 2:0]      icache_rd_type,
    input  wire 	[31:0]      icache_rd_addr,
    output  wire            	icache_rd_rdy,		
    output   wire           	icache_ret_valid,	
	output	wire				icache_ret_last,
    output  wire	[31:0]      icache_ret_data,
    // data sram interface
    input   wire            	data_sram_req,
    input   wire            	data_sram_wr,
    input   wire	[ 1:0]      data_sram_size,
    input   wire	[31:0]      data_sram_addr,
    input   wire	[31:0]      data_sram_wdata,
    input   wire	[ 3:0]      data_sram_wstrb,
    output  wire            data_sram_addr_ok,
    output   wire           data_sram_data_ok,
    output  wire[31:0]      data_sram_rdata
);


//第一部分：ar通道
localparam AR_INIT       = 3'b001,  // 初始状态：等待读请求
           AR_INST       = 3'b010,  // 指令读状态：正在向 AXI 发送指令读地址
           AR_DATA       = 3'b100;  // 数据读状态：正在向 AXI 发送数据读地址


reg [2:0]       ar_state;
reg [2:0]       ar_next_state;
reg [31:0]      ar_addr_reg;
reg [7:0]       arlen_reg;
always @(posedge aclk) begin
    if (~aresetn)
        ar_state <= AR_INIT;
    else
        ar_state <= ar_next_state;
end
always @(*) begin
    case (ar_state)
        AR_INIT: begin
            //data和inst请求同时来的时候，data优先
            if (data_sram_req && ~data_sram_wr) 
                ar_next_state = AR_DATA;
            else if (icache_rd_req)
                ar_next_state = AR_INST;
            else
                ar_next_state = AR_INIT;
        end
        //AXI 握手完成（arvalid && arready），回到初始态
        AR_INST: begin
            if (arvalid && arready)
                ar_next_state = AR_INIT;
            else
                ar_next_state = AR_INST;
        end
        //AXI 握手完成（arvalid && arready），回到初始态
        AR_DATA: begin
            if (arvalid && arready)
                ar_next_state = AR_INIT;
            else
                ar_next_state = AR_DATA;
        end
        default: ar_next_state = AR_INIT;
    endcase
end

always @(posedge aclk) begin
    if (!aresetn) begin
        arid <= 4'b0;
        ar_addr_reg <= 32'b0;
        arlen_reg <= 8'b0;
    end 
    // 仅初始态更新（避免重复锁存
    else if (ar_state == AR_INIT) begin
        if (data_sram_req && ~data_sram_wr) begin
            ar_addr_reg <= data_sram_addr;
            arid <= 4'b0001;
            arlen_reg <= 8'b0;
        end else if (icache_rd_req) begin
            ar_addr_reg <= icache_rd_addr;
            arid <= 4'b0000;
            arlen_reg <= 8'b11;
        end
    end
end

assign araddr = ar_addr_reg;
assign icache_rd_rdy = arready && (arid == 4'b0000);
assign data_sram_addr_ok = arvalid && arready && (arid == 4'b0001) || b_state == B_DATA_READY ;
assign arvalid = (ar_state == AR_INST) || (ar_state == AR_DATA);
assign arlen = arlen_reg;
assign arburst = 2'b01;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arsize = 3'b010;

//统计已发送但未完成的读地址数
//ar-r
reg [1:0]       ar_counter_reg;
always @(posedge aclk) begin
    if (!aresetn)
        ar_counter_reg <= 2'b0;
    else 
        ar_counter_reg <= ar_counter_reg+ (arvalid && arready ? 1'b1 : 1'b0) - (rvalid && rready && rlast ? 1'b1 : 1'b0);

end

//第二部分：r通道
localparam  R_INIT   	= 3'b001,
			R_DATA	    = 3'b010,
            R_DATA_OVER = 3'b100;
reg [2:0]       r_state;
reg [2:0]       r_next_state;
reg [31:0]      r_rdata_reg;
reg [3:0]       r_rid_reg;
reg        icache_ret_valid_r;
reg [31:0] icache_ret_data_r;
reg        icache_ret_last_r;
always @(posedge aclk) begin
    if (!aresetn)
        r_state <= R_INIT;
    else
        r_state <= r_next_state;
end
always @(*) begin
    case (r_state)
        R_INIT: begin
            // arvalid && arready：AR 通道刚完成读地址握手（读传输正式启动）
            // ar_counter_reg != 2'b0：已有发送但未完成的读地址
            if (arvalid && arready || ar_counter_reg != 2'b0) 
                r_next_state = R_DATA;
            else
                r_next_state = R_INIT;
        end
        // 数据接收态：等待 AXI 读数据握手（rvalid && rready），完成后进入读完成态
        R_DATA: begin
            if (rvalid && rready && rlast)
                r_next_state = R_DATA_OVER;
            else
                r_next_state = R_DATA;
        end
        R_DATA_OVER: begin
            r_next_state = R_INIT;
        end
        default: r_next_state = R_INIT;
    endcase
end

always @(posedge aclk)  begin
	if(~aresetn) begin
		r_rid_reg <= 4'b0;
        r_rdata_reg <= 32'b0;
    end else if(rvalid && rready) begin
        // 握手成功：锁存数据和 ID
		r_rid_reg <= rid;
        r_rdata_reg <= rdata;
    end
end	

always @(posedge aclk) begin
  if(!aresetn) begin
    icache_ret_valid_r <= 1'b0;
    icache_ret_data_r  <= 32'b0;
    icache_ret_last_r  <= 1'b0;
  end else begin
    icache_ret_valid_r <= (rvalid && rready && (rid == 4'b0000));
    if(rvalid && rready && (rid == 4'b0000)) begin
      icache_ret_data_r <= rdata;
      icache_ret_last_r <= rlast;   
    end else begin
      icache_ret_last_r <= 1'b0;
    end
  end
end


assign data_sram_rdata = (r_rid_reg == 4'b0001) ? r_rdata_reg : 32'b0;
assign rready = (r_state == R_DATA);
assign data_sram_data_ok = ((r_state == R_DATA_OVER) && (r_rid_reg == 4'b0001)) || (b_state == B_DATA_END);
assign icache_ret_valid = icache_ret_valid_r;
assign icache_ret_data  = icache_ret_data_r;
assign icache_ret_last  = icache_ret_last_r;


//第三部分：aw通道
localparam AW_INIT       = 5'b00001,
           AW_ADDR_READY = 5'b00100,
           AW_DATA_READY = 5'b01000,
           AW_NO_READY   = 5'b00010,
           AW_END_READY  = 5'b10000;
reg [4:0]       aw_state;
reg [4:0]       aw_next_state;
reg [31:0]      aw_addr_reg;
reg [31:0]       aw_data_reg;
reg [3:0]        aw_wstrb_reg;
always @(posedge aclk) begin
    if (~aresetn)
        aw_state <= AW_INIT;
    else
        aw_state <= aw_next_state;
end
always @(*) begin
    case (aw_state)
        AW_INIT: begin
            if (data_sram_req && data_sram_wr) 
                aw_next_state = AW_NO_READY;
            else
                aw_next_state = AW_INIT;
        end
        AW_NO_READY: begin
            if (awvalid && awready && wvalid && wready)
                aw_next_state =  AW_END_READY;
            else if (awvalid && awready)
                aw_next_state = AW_DATA_READY;
            else if (wvalid && wready)
                aw_next_state = AW_ADDR_READY;
            else
                aw_next_state = AW_NO_READY;
        end
        AW_ADDR_READY: begin
            if (awvalid && awready)
                aw_next_state =  AW_END_READY;
            else
                aw_next_state = AW_ADDR_READY;
        end
        AW_DATA_READY: begin
            if (wvalid && wready)
                aw_next_state =  AW_END_READY;
            else
                aw_next_state = AW_DATA_READY;
                end
        AW_END_READY: begin
            if (bvalid && bready)
                aw_next_state =  AW_INIT;
            else
                aw_next_state = AW_END_READY;
        end
        default: aw_next_state = AW_INIT;
    endcase
end

always @(posedge aclk) begin
    if (~aresetn) begin
        aw_addr_reg <= 32'b0;
        aw_data_reg <= 32'b0;
        aw_wstrb_reg <= 4'b0;
        awsize <= 3'b0;
    end 
    else if (aw_state == AW_INIT) begin
        if (data_sram_req && data_sram_wr) begin
            // 数据 SRAM 写请求：锁存所有写信号
            aw_addr_reg <= data_sram_addr;
            aw_data_reg <= data_sram_wdata;
            aw_wstrb_reg <= data_sram_wstrb;
            awsize <= {1'b0, data_sram_size};
        end 
    end
end



assign awvalid = (aw_state == AW_ADDR_READY) || (aw_state == AW_NO_READY);
assign wvalid = (aw_state == AW_DATA_READY) || (aw_state == AW_NO_READY);
assign awid = 4'b1;
assign awlen = 8'b0;
assign awburst = 2'b01;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign wlast = 1'b1;
assign wid = 4'b1;
assign awaddr = aw_addr_reg;
assign wdata = aw_data_reg;
assign wstrb = aw_wstrb_reg;

//第四部分：b通道
localparam B_INIT       = 3'b001,  // 初始状态：等待 W 通道写数据传输完成
           B_DATA_READY = 3'b010,  // 响应接收状态：准备接收 AXI 从设备的写响应
           B_DATA_END   = 3'b100;  // 响应完成状态：写响应已接收，写传输正式结束

reg [2:0]       b_state;
reg [2:0]       b_next_state;
always @(posedge aclk) begin
    if (~aresetn)
        b_state <= B_INIT;
    else
        b_state <= b_next_state;

end
always @(*) begin
    case (b_state)
        B_INIT: begin
            // 1. aw_state == AW_DATA_READY：当前处于 W 通道数据传输状态（确保是写操作流程）
            // 2. wvalid && wready：W 通道握手成功（写数据已被从设备接收）
            if (aw_state == AW_NO_READY && awvalid && awready && wvalid && wready ||
            aw_state == AW_ADDR_READY && awvalid && awready || aw_state == AW_DATA_READY && wvalid && wready) 
                b_next_state = B_DATA_READY;
            else
                b_next_state = B_INIT;
        end
        B_DATA_READY: begin
            // 响应接收态：等待 B 通道握手（bvalid && bready），完成后进入响应完成态
            if (bvalid && bready)
                b_next_state = B_DATA_END;
            else
                b_next_state = B_DATA_READY;
        end
        B_DATA_END: begin
            // 响应完成态：写响应已接收，写传输正式结束，回到初始态，停一拍为了唤醒dataok
            b_next_state = B_INIT;
        end
        default: b_next_state = B_INIT;
    endcase
end
assign bready = aw_state == AW_END_READY;
endmodule
           

           
