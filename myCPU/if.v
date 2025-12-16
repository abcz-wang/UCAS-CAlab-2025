`include "defines.vh"

module if_stage(
    input     wire                      clk         ,
    input     wire                      reset       ,
    input     wire                      ID_allow    ,
    input  wire [`ID2IF_BUS_LEN -1:0] ID_to_IF_bus         ,
    output      wire                    IF_to_ID_valid ,
    output wire [`IF2ID_BUS_LEN -1:0] IF_to_ID_bus   ,
    // inst sram interface
    output wire [31:0] inst_sram_addr ,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire         inst_sram_req,//    1           
    output wire [ 3:0]  inst_sram_wr,// 4           
    output wire [ 1:0]  inst_sram_size, //2     
    output wire [ 3:0]  inst_sram_wstrb,     
    input  wire         inst_sram_addr_ok,
    input  wire         inst_sram_data_ok, 
	//csr
	input wire wb_ex,
	input wire [31:0]ex_entry,
	input wire ertn_flush,
	input wire [31:0]era_pc,
    // task 19
    output wire [18:0] s0_vppn,
    output wire        s0_va_bit12,
    input  wire        s0_found,
    input  wire [$clog2(`TLBNUM)-1:0] s0_index,
    input  wire [19:0] s0_ppn,
    input  wire [ 5:0] s0_ps,
    input  wire [ 1:0] s0_plv,
    input  wire        s0_v,
    input  wire [ 1:0] crmd_plv_fromCSR,
    // DMW0
    input  wire        csr_dmw0_plv0,
    input  wire        csr_dmw0_plv3,
    input  wire [ 2:0] csr_dmw0_pseg,
    input  wire [ 2:0] csr_dmw0_vseg,
    // DMW1
    input  wire        csr_dmw1_plv0,   
    input  wire        csr_dmw1_plv3,
    input  wire [ 2:0] csr_dmw1_pseg,
    input  wire [ 2:0] csr_dmw1_vseg,
    input  wire        csr_direct_addr
);
wire         br_taken;
wire [ 31:0] br_target;
wire         br_stall;
wire         pre_IF_ready_go;
reg          IF_valid;
wire         IF_ready_go;
wire         IF_allow;
wire         pre_IF_valid;
wire [31:0]  seq_pc;

// task 19
//wire [31:0]  nextpc;
wire [31:0] nextpc_vrtl;
wire [31:0] nextpc_phy;

wire [`EXC_WIDTH-1:0]exc_last;
wire [`EXC_WIDTH-1:0]exc_now;
reg wb_ex_r;
reg ertn_flush_r;
reg br_taken_r;
reg [31:0] ex_entry_r;
reg [31:0] era_pc_r;
reg [31:0] br_target_r;
wire [31:0] IF_inst;
reg  [31:0] IF_pc;
reg exc_adef;
reg inst_sram_req_reg;
reg discard_inst;
wire [31:0] save_inst;

// task 19
wire [ 7:0] IF_exc_tlb;

// addr translation
wire        dmw0_hit;   // if hit
wire        dmw1_hit;
wire [31:0] dmw0_paddr; // mapped phyaddr
wire [31:0] dmw1_paddr;
wire [31:0] tlb_paddr ; // translated phyaddr
wire        tlb_used  ; // trans done via tlb

always @(posedge clk) begin
    if (reset)
        exc_adef <= 1'b0;
    else
        exc_adef <= (nextpc_vrtl[1:0] != 2'b00);
end

assign exc_last = 16'b0;
assign exc_now = exc_last | { {(`EXC_WIDTH-`EXC_ADEF-1){1'b0}}, exc_adef, {`EXC_ADEF{1'b0}} };

assign {br_stall, br_taken, br_target} = ID_to_IF_bus;

assign IF_to_ID_bus = {IF_exc_tlb,
                        exc_now,
						IF_inst ,
                    	IF_pc   };

// pre-IF stage
assign pre_IF_ready_go = inst_sram_req && inst_sram_addr_ok;
assign pre_IF_valid  = ~reset && pre_IF_ready_go;
assign seq_pc       = IF_pc + 3'h4;
assign nextpc_vrtl  = wb_ex_r? ex_entry_r: wb_ex? ex_entry:
                      ertn_flush_r? era_pc_r: ertn_flush? era_pc:
                      br_taken_r? br_target_r: br_taken ? br_target : seq_pc;

// IF stage
//此时dataok到来，或者有有效的缓存指令，而且不需要丢弃当前指令                   
assign IF_ready_go = ~br_taken && (~discard_inst) && ((save_inst != 0) || inst_sram_data_ok); 
assign IF_allow     = !IF_valid || IF_ready_go && ID_allow;  
//后一半是同一拍地址与数据握手成功，好像不会发生
assign IF_to_ID_valid =  (IF_valid && IF_ready_go) || (~IF_valid && inst_sram_data_ok);   
always @(posedge clk) begin
    if (reset) begin
        IF_valid <= 1'b0;
    end
    else if (IF_allow) begin
        IF_valid <= pre_IF_valid;   
    end
end
always @(posedge clk) begin
    if (reset) begin
        IF_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (pre_IF_valid &&((IF_allow||((br_taken||br_taken_r) ))||(wb_ex || wb_ex_r)||(ertn_flush || ertn_flush_r))) begin
        IF_pc <= nextpc_vrtl ;
    end
end
//一堆寄存器
always @(posedge clk) begin
    if(reset) begin
        {wb_ex_r, ertn_flush_r, br_taken_r} <= 3'b0;
        {ex_entry_r, era_pc_r, br_target_r} <= {3{32'b0}};
    end
    else if(wb_ex) begin
        ex_entry_r <= ex_entry;
        wb_ex_r <= 1'b1;
    end
    else if(ertn_flush) begin
        era_pc_r <= era_pc;
        ertn_flush_r <= 1'b1;
    end    
    else if(br_taken ) begin
        br_target_r <= br_target;
        br_taken_r <= 1'b1;
    end
    else if(inst_sram_addr_ok && ~discard_inst) begin
        {wb_ex_r, ertn_flush_r, br_taken_r} <= 3'b0;
    end
end
//用于分支或者跳转指令到来的时候，丢弃已经请求握手成功但还没有返回的指令
always @(posedge clk) begin
    if(reset)
        discard_inst <= 1'b0;
    else if((wb_ex || ertn_flush || br_taken || br_stall) && pre_IF_ready_go)
        discard_inst <= 1'b1;
    else if(~IF_allow && (wb_ex || ertn_flush || br_taken || br_stall) && ~IF_ready_go)
        discard_inst <= 1'b1;
    else if(inst_sram_data_ok)
        discard_inst <= 1'b0;
end

//save_inst寄存器，在有效指令已经来了但是id不让进的时候保存
reg [31:0] save_inst_reg;
assign save_inst = save_inst_reg;
always @(posedge clk) begin
    if(reset)
        save_inst_reg <= 0;
    else if(IF_ready_go) begin
        if(wb_ex || ertn_flush)
            save_inst_reg <= 0;
        else if(!ID_allow && save_inst_reg == 0)
            save_inst_reg <= inst_sram_rdata;
        else if(!ID_allow)
            save_inst_reg <= save_inst;
        else 
            save_inst_reg <= 0;
    end
end

//req的reg寄存器，防止连续请求
always @(posedge clk) begin
    if(reset)
        inst_sram_req_reg <= 1'b1;
    else if(inst_sram_req && inst_sram_addr_ok)
        inst_sram_req_reg <= 1'b0;
    else if(inst_sram_data_ok)
        inst_sram_req_reg <= 1'b1;
end
//wire inst_sram_req_reg_r = inst_sram_req_reg & ~inst_sram_data_ok;
assign IF_inst         = (save_inst == 0) ? inst_sram_rdata : save_inst;
assign inst_sram_req = (((IF_allow||(br_taken||br_taken_r))  && ~br_stall) 
                        ||(wb_ex || wb_ex_r)||(ertn_flush || ertn_flush_r)) && ~reset && (inst_sram_req_reg ) ; 
assign inst_sram_wr    = 4'b0;   
assign inst_sram_wstrb = 4'b0;   
assign inst_sram_addr  = nextpc_phy;
assign inst_sram_wdata = 32'b0;
assign inst_sram_size  = 3'b0;

// task 19
assign {s0_vppn, s0_va_bit12} = nextpc_vrtl[31:12];
// if in the correct virt segment and have right privs
assign dmw0_hit  = (nextpc_vrtl[31:29] == csr_dmw0_vseg) && (crmd_plv_fromCSR == 2'd0 && csr_dmw0_plv0 || crmd_plv_fromCSR == 2'd3 && csr_dmw0_plv3);
assign dmw1_hit  = (nextpc_vrtl[31:29] == csr_dmw1_vseg) && (crmd_plv_fromCSR == 2'd0 && csr_dmw1_plv0 || crmd_plv_fromCSR == 2'd3 && csr_dmw1_plv3);
// mapped phyaddr
assign dmw0_paddr = {csr_dmw0_pseg, nextpc_vrtl[28:0]};
assign dmw1_paddr = {csr_dmw1_pseg, nextpc_vrtl[28:0]};
// tlb phyaddr
assign tlb_paddr  = (s0_ps == 6'd22) ? {s0_ppn[19:10], nextpc_vrtl[21:0]} : {s0_ppn, nextpc_vrtl[11:0]}; // 根据Page Size决定
assign nextpc_phy = csr_direct_addr ? nextpc_vrtl :
                    dmw0_hit        ? dmw0_paddr  :
                    dmw1_hit        ? dmw1_paddr  :
                                      tlb_paddr   ;     

assign tlb_used = ~csr_direct_addr && ~dmw0_hit && ~dmw1_hit;
assign {IF_exc_tlb[`EARRAY_PIL],IF_exc_tlb[`EARRAY_PIS],IF_exc_tlb[`EARRAY_PME],IF_exc_tlb[`EARRAY_TLBR_MEM], IF_exc_tlb[`EARRAY_PPI_MEM]} = 5'h0;
assign IF_exc_tlb[`EARRAY_TLBR_FETCH] = IF_valid & tlb_used & ~s0_found; // not hit
assign IF_exc_tlb[`EARRAY_PIF ] = IF_valid & tlb_used & ~IF_exc_tlb[`EARRAY_TLBR_FETCH] & ~s0_v; // fetch page fault
assign IF_exc_tlb[`EARRAY_PPI_FETCH ] = IF_valid & tlb_used & ~IF_exc_tlb[`EARRAY_PIF ] & (crmd_plv_fromCSR > s0_plv); // priv page fault


endmodule
