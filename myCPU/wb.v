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
	input wire [31:0] csr_rvalue
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

assign {WB_gr_we       ,  
        WB_dest        ,  
        WB_final_result,  
        WB_pc,
		WB_exc_last,
		WB_csr_access,
		WB_ertn_flush,
		WB_res_from_csr
} = MEM_to_WB_bus_reg;

assign WB_exc_now = WB_exc_last;
wire [5:0]wb_ecode;
wire [8:0]wb_esubcode;
//注意各个例外有优先级！我写的代码已经加上了优先级，后面如果补充例外，先看指令集手册关于优先级的要求！
assign wb_ecode = {6{WB_exc_now[`EXC_INT]}} & `ECODE_INT |
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
				{6{WB_exc_now[`EXC_TLBR]}} & `ECODE_TLBR;

assign wb_esubcode = {9{WB_exc_now[`EXC_ADEM]}} & `ESUBCODE_ADEM;
wire wb_ex = |WB_exc_now;
wire [31:0]wb_vaddr = WB_final_result;
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
        else begin
			
		end
    end
end



assign rf_we    = WB_gr_we && WB_valid && ~wb_ex;
assign rf_waddr = WB_dest;
assign rf_wdata = WB_res_from_csr?csr_rvalue:WB_final_result;
assign WB_to_ID_dest = WB_dest & {5{WB_valid}};
// debug info
assign debug_wb_pc       = WB_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = WB_dest;
assign debug_wb_rf_wdata = rf_wdata;
endmodule
