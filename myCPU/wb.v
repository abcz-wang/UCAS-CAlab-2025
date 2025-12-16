`include "defines.vh"
module wb_stage(
    input     wire                       clk           ,
    input     wire                       reset         ,
    output    wire                       WB_allow    ,
    input      wire                      MEM_to_WB_valid,
    input  wire [`MEM2WB_BUS_LEN-1:0]  MEM_to_WB_bus  ,
    output wire [`WB2ID_BUS_LEN-1:0]  WB_to_ID_bus  ,
    output wire [31:0] debug_wb_pc     ,
    output wire [ 3:0] debug_wb_rf_we  ,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [`WB_BYPASS_LEN-1:0] WB_to_ID_forward,
	output wire [`WB2CSR_BUS_LEN-1:0] WB2CSR_bus,
	output wire [79:0] WB_csr_access,
	input wire [31:0] csr_rvalue,
    // task 18
    output wire                         inst_wb_tlbfill,
    output wire                         inst_wb_tlbsrch,
    output wire                         tlbwe,
    output wire                         inst_wb_tlbrd,
    output wire                         wb_tlbsrch_found,
    output wire [               3:0]    wb_tlbsrch_idxgot,
    output wire                         WB_refetch_flush,
    // task 19
    output wire                         wb_ex_e,
    output wire                         WB_exc_fetch
);

reg         WB_valid;
wire        WB_ready_go;

reg [`MEM2WB_BUS_LEN-1:0] MEM_to_WB_bus_reg;
wire        WB_gr_we;
wire [ 4:0] WB_dest;
wire [31:0] WB_final_result;
wire [31:0] WB_pc;
wire [ 4:0] WB_to_ID_dest;
wire [`EXC_WIDTH-1:0]WB_exc_last;
wire [`EXC_WIDTH-1:0]WB_exc_now;
wire WB_ertn_flush;
wire WB_res_from_csr;

// task 18
wire  [ 9:0] MEM_to_WB_tlb_bus;
wire         inst_wb_tlbwr;
wire         wb_refetch_flag;
wire  [ 7:0] WB_exc_tlb;
wire  [31:0] wb_vaddr;


assign {wb_vaddr,
        WB_exc_tlb,
        MEM_to_WB_tlb_bus,
        WB_gr_we       ,  
        WB_dest        ,  
        WB_final_result,  
        WB_pc,
		WB_exc_last,
		WB_csr_access,
		WB_ertn_flush,
		WB_res_from_csr
} = MEM_to_WB_bus_reg;

assign WB_exc_now = WB_exc_last | {1'b0, WB_exc_tlb[`EARRAY_TLBR_FETCH] | WB_exc_tlb[`EARRAY_TLBR_MEM], 9'b0, WB_exc_tlb[`EARRAY_PPI_FETCH] | WB_exc_tlb[`EARRAY_PPI_MEM], WB_exc_tlb[`EARRAY_PME], WB_exc_tlb[`EARRAY_PIF], WB_exc_tlb[`EARRAY_PIS], WB_exc_tlb[`EARRAY_PIL], 1'b0};
wire [5:0]wb_ecode;
wire [8:0]wb_esubcode;
//注意各个例外有优先级！我写的代码已经加上了优先级，后面如果补充例外，先看指令集手册关于优先级的要求！
/* assign wb_ecode = {6{WB_exc_now[`EXC_INT]}} & `ECODE_INT |
				{6{WB_exc_now[`EXC_PIL]}} & `ECODE_PIL |
				{6{WB_exc_now[`EXC_PIS]}} & `ECODE_PIS |
				{6{WB_exc_now[`EXC_PIF]}} & `ECODE_PIF |
				{6{WB_exc_now[`EXC_PME]}} & `ECODE_PME |
				{6{WB_exc_now[`EXC_PPI]}} & `ECODE_PPI |
				{6{WB_exc_now[`EXC_ADEF]}} & `ECODE_ADE |
				{6{WB_exc_now[`EXC_ADEM]}} & `ECODE_ADE |
				{6{WB_exc_now[`EXC_ALE]}} & `ECODE_ALE |
				{6{WB_exc_now[`EXC_SYS]}} & `ECODE_SYS |
				{6{WB_exc_now[`EXC_BRK]}} & `ECODE_BRK |
				{6{WB_exc_now[`EXC_INE]}} & `ECODE_INE |
				{6{WB_exc_now[`EXC_IPE]}} & `ECODE_IPE |
				{6{WB_exc_now[`EXC_FPD]}} & `ECODE_FPD |
				{6{WB_exc_now[`EXC_FPE]}} & `ECODE_FPE |
				{6{WB_exc_now[`EXC_TLBR]}} & `ECODE_TLBR; */

assign wb_ecode = WB_exc_now[`EXC_INT] ? `ECODE_INT :
                  WB_exc_now[`EXC_ADEF] ? `ECODE_ADE :
                  WB_exc_tlb[`EARRAY_TLBR_FETCH] ? `ECODE_TLBR :
                  WB_exc_now[`EXC_PIF] ? `ECODE_PIF :
                  WB_exc_tlb[`EARRAY_PPI_FETCH] ? `ECODE_PPI :
                  WB_exc_now[`EXC_ALE] ? `ECODE_ALE :
                  WB_exc_now[`EXC_ADEM] ? `ECODE_ADE :
                  WB_exc_tlb[`EARRAY_TLBR_MEM] ? `ECODE_TLBR :
                  WB_exc_now[`EXC_PIL] ? `ECODE_PIL :
                  WB_exc_now[`EXC_PIS] ? `ECODE_PIS :
                  WB_exc_now[`EXC_PME] ? `ECODE_PME :
                  WB_exc_tlb[`EARRAY_PPI_MEM] ? `ECODE_PPI :
                  WB_exc_now[`EXC_SYS] ? `ECODE_SYS :
                  WB_exc_now[`EXC_BRK] ? `ECODE_BRK :
                  WB_exc_now[`EXC_INE] ? `ECODE_INE :
                  6'b0;

assign wb_esubcode = {9{WB_exc_now[`EXC_ADEM]}} & `ESUBCODE_ADEM;
wire wb_ex = |WB_exc_now;
assign wb_ex_e = wb_ex;
assign WB2CSR_bus = {
	WB_ertn_flush,
	wb_ex,
	wb_ecode,
	wb_esubcode,
	WB_pc,
	wb_vaddr
};

wire  rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign WB_to_ID_bus = {rf_we   ,  
                       rf_waddr, 
                       rf_wdata   
                      };
assign WB_to_ID_forward = {WB_gr_we,
                         WB_to_ID_dest,
                         rf_wdata,
						 WB_res_from_csr
                        };

assign WB_ready_go = 1'b1;
assign WB_allow  = !WB_valid || WB_ready_go;

always @(posedge clk) begin
    if (reset) begin
        WB_valid <= 1'b0;
        MEM_to_WB_bus_reg <= {`MEM2WB_BUS_LEN{1'b0}};
    end
    else if (WB_allow) begin
        WB_valid <= MEM_to_WB_valid;
        if (MEM_to_WB_valid)
            MEM_to_WB_bus_reg <= MEM_to_WB_bus;
    end
end



assign rf_we    = WB_gr_we && WB_valid && ~wb_ex;
assign rf_waddr = WB_dest;
assign rf_wdata = WB_res_from_csr?csr_rvalue:WB_final_result;
assign WB_to_ID_dest = WB_dest & {5{WB_valid}};

assign {wb_refetch_flag, inst_wb_tlbsrch, inst_wb_tlbrd, inst_wb_tlbwr, inst_wb_tlbfill, wb_tlbsrch_found, wb_tlbsrch_idxgot} = MEM_to_WB_tlb_bus;
assign tlbwe = (inst_wb_tlbwr || inst_wb_tlbfill) && WB_valid;
assign WB_refetch_flush = wb_refetch_flag && WB_valid;
assign WB_exc_fetch = WB_exc_now[`EXC_ADEF] | WB_exc_tlb[`EARRAY_TLBR_FETCH] | WB_exc_tlb[`EARRAY_PIF] | WB_exc_tlb[`EARRAY_PPI_FETCH];

// debug info
assign debug_wb_pc       = WB_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = WB_dest;
assign debug_wb_rf_wdata = rf_wdata;



endmodule