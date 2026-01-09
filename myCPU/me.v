`include "defines.vh"
module mem_stage(
    input       wire                    clk           ,
    input       wire                   reset         ,
    input       wire                   WB_allow    ,
    output      wire                   MEM_allow    ,
    input       wire                   EX_to_MEM_valid,
    input  wire[`EX2MEM_BUS_LEN-1:0] EX_to_MEM_bus  ,
    output       wire                  MEM_to_WB_valid,
    output wire[`MEM2WB_BUS_LEN-1:0] MEM_to_WB_bus  ,
    //from data-sram
    input  wire[31:0] data_sram_rdata,
    output wire [`MEM_BYPASS_LEN-1:0] MEM_to_ID_forward,
    input wire          data_sram_data_ok,
    output wire [15:0] MEM_tlb_stall_bus
);

reg         MEM_valid;
wire        MEM_ready_go;

reg [`EX2MEM_BUS_LEN-1:0] EX_to_MEM_bus_reg;
wire        MEM_res_from_mem;
wire        MEM_gr_we;
wire [ 4:0] MEM_dest;
wire [31:0] MEM_alu_result;
wire [31:0] MEM_pc;
wire        MEM_is_ld_b;
wire        MEM_is_ld_h;
wire        MEM_is_ld_bu;
wire        MEM_is_ld_hu;

wire [`EXC_WIDTH-1:0]MEM_exc_last;
wire [`EXC_WIDTH-1:0]MEM_exc_now;
wire [79:0]MEM_csr_access;
wire MEM_ertn_flush;
wire MEM_res_from_csr;
wire        data_ok_mem_id;
wire [31:0] load_res;

wire [31:0] mem_result;
wire [31:0] MEM_final_result;
wire [ 4:0] MEM_to_ID_dest;
wire MEM_req;

// task 18
wire  [ 9:0] EX_to_MEM_tlb_bus;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        MEM_refetch_flag;
wire        tlbsrch_found;
wire [ 3:0] tlbsrch_idxgot;
wire [ 9:0] MEM_to_WB_tlb_bus;
//csr
wire [13:0] MEM_csr_num;
wire        MEM_csr_we;
wire [31:0] MEM_csr_wmask;
wire [31:0] MEM_csr_wvalue;
wire [78:0] MEM_csr_access_b;

// task 19
wire [7:0] EX_to_MEM_exc_tlb;
wire [7:0] MEM_to_WB_exc_tlb;

// task 23
wire MEM_cacop;

assign {MEM_cacop,
        EX_to_MEM_exc_tlb,
        EX_to_MEM_tlb_bus,
        MEM_res_from_mem,
        MEM_gr_we       ,
        MEM_dest        ,
        MEM_alu_result  ,
        MEM_pc          ,
        MEM_is_ld_b     ,
        MEM_is_ld_h     ,
        MEM_is_ld_bu    ,
        MEM_is_ld_hu,
		MEM_exc_last,
		MEM_csr_access,
		MEM_ertn_flush,
		MEM_res_from_csr,
        MEM_req
} = EX_to_MEM_bus_reg;
assign MEM_exc_now = MEM_exc_last;
assign MEM_to_WB_bus = {MEM_cacop,
                        MEM_alu_result,
                        MEM_to_WB_exc_tlb,
                        MEM_to_WB_tlb_bus,
                        MEM_gr_we       , 
                        MEM_dest        ,  
                        MEM_final_result, 
                        MEM_pc,
                        MEM_exc_now,
                        MEM_csr_access,
                        MEM_ertn_flush,
                        MEM_res_from_csr
                      };
assign MEM_to_ID_forward = {MEM_gr_we,
                         MEM_to_ID_dest,
                         MEM_final_result,
						 MEM_res_from_csr,
                         data_ok_mem_id
                        };
//不是load应该直接走，是就等数据返回，但防止store乱了，所以store也一起等
assign MEM_ready_go    = (~MEM_req | (MEM_req & data_sram_data_ok));
assign MEM_allow     = !MEM_valid || MEM_ready_go && WB_allow;
assign MEM_to_WB_valid = MEM_valid && MEM_ready_go;
always @(posedge clk) begin
    if (reset) begin
        MEM_valid <= 1'b0;
        EX_to_MEM_bus_reg <= {`EX2MEM_BUS_LEN{1'b0}};
    end
    else if (MEM_allow) begin
        MEM_valid <= EX_to_MEM_valid;
        if (EX_to_MEM_valid)
            EX_to_MEM_bus_reg <= EX_to_MEM_bus;
        else begin
			
		end

    end
end


assign load_res         = (MEM_is_ld_b || MEM_is_ld_bu) ?
                            (MEM_alu_result[1:0] == 2'b00) ? {24'b0, data_sram_rdata[7:0]}   :
                            (MEM_alu_result[1:0] == 2'b01) ? {24'b0, data_sram_rdata[15:8]}  :
                            (MEM_alu_result[1:0] == 2'b10) ? {24'b0, data_sram_rdata[23:16]} :
                            {24'b0, data_sram_rdata[31:24]} :
                          (MEM_is_ld_h || MEM_is_ld_hu) ?
                            (MEM_alu_result[1] == 1'b0)    ? {16'b0, data_sram_rdata[15:0]} :
                            {16'b0, data_sram_rdata[31:16]} :
                          32'b0;

assign MEM_to_ID_dest   = MEM_dest & {5{MEM_valid}};
assign mem_result       = (MEM_is_ld_b)  ? ({{24{load_res[7]}}, load_res[7:0]})   :
                          (MEM_is_ld_bu) ? ({24'b0, load_res[7:0]}):
                          (MEM_is_ld_h)  ? ({{16{load_res[15]}}, load_res[15:0]}) :
                          (MEM_is_ld_hu) ? ({16'b0, load_res[15:0]}) :
                          data_sram_rdata;
assign MEM_final_result = MEM_res_from_mem ? mem_result : MEM_alu_result;
//load而且成功返回数据，告诉id不用阻塞
assign data_ok_mem_id = MEM_req && data_sram_data_ok;

// task 18
assign {MEM_refetch_flag, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, tlbsrch_found, tlbsrch_idxgot} = EX_to_MEM_tlb_bus;
assign MEM_to_WB_tlb_bus = EX_to_MEM_tlb_bus;
assign MEM_csr_access_b = {MEM_csr_access[79:66], MEM_csr_access[64:0]};
assign {MEM_csr_num, MEM_csr_we, MEM_csr_wvalue, MEM_csr_wmask} = MEM_csr_access_b;
assign MEM_tlb_stall_bus = {inst_tlbrd & MEM_valid, MEM_csr_we & MEM_valid, MEM_csr_num};
// task 19
assign MEM_to_WB_exc_tlb = EX_to_MEM_exc_tlb;


endmodule