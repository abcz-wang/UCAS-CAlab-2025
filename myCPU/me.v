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
    input wire          data_sram_data_ok
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

wire [31:0] load_res;

wire [31:0] mem_result;
wire [31:0] MEM_final_result;
wire [ 4:0] MEM_to_ID_dest;
wire MEM_req;
assign {MEM_res_from_mem,
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
assign MEM_to_WB_bus = {MEM_gr_we       , 
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
						 MEM_res_from_csr
                        };
assign MEM_ready_go    = ~MEM_req | (MEM_req & data_sram_data_ok);
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




endmodule