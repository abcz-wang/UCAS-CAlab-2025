`include "defines.vh"
module ex_stage(
    input        wire                   clk           ,
    input         wire                  reset         ,
    input          wire                 MEM_allow    ,
    output        wire                  EX_allow    ,
    input         wire                  ID_to_EX_valid,
    input  wire [`ID2EX_BUS_LEN -1:0] ID_to_EX_bus  ,
    output          wire                EX_to_MEM_valid,
    output wire [`EX2MEM_BUS_LEN-1:0] EX_to_MEM_bus  ,
	output  wire      EX_to_ID_load_up,  
    // data sram interface(write)
    //output  wire       data_sram_en   ,
    //output wire [ 3:0] data_sram_we   ,
    output              data_sram_req,
    output              data_sram_wr,
    output [1:0]        data_sram_size,
    output [3:0]        data_sram_wstrb,
    input               data_sram_addr_ok,
    output wire [31:0] data_sram_addr ,
    output wire [31:0] data_sram_wdata,
    output wire [`EX_BYPASS_LEN-1:0] EX_to_ID_forward,
	input wire has_exc,//MEM,WB级有异常指令，不写入mem
	input wire has_ertn, //MEM,WB级是ertn,也不能写入mem,因为要清空流??
	input wire [63:0]glob_cnt 
);

reg         EX_valid      ;
wire        EX_ready_go   ;

reg  [`ID2EX_BUS_LEN -1:0] ID_to_EX_bus_reg;

wire [3:0] write_strb;

wire [14:0] EX_alu_op;
wire        EX_res_from_mem;
wire        EX_gr_we;
wire        EX_mem_we;
wire [4: 0] EX_dest;
wire [31:0] EX_rkd_value;
wire [31:0] EX_pc;
wire [31:0] EX_alu_src1   ;
wire [31:0] EX_alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] ex_final_result ;
wire [31:0]div_result;
wire div_done;
wire is_div;
wire [4:0] EX_to_ID_dest;
wire EX_is_div_mod_s;
wire EX_is_div_mod_u;
wire EX_div_or_mod;
wire EX_is_ld_b;
wire EX_is_ld_h;
wire EX_is_ld_bu;
wire EX_is_ld_hu;
wire EX_is_st_b;
wire EX_is_st_h;
wire EX_is_st_w;
wire [`EXC_WIDTH-1:0]EX_exc_last;
wire [`EXC_WIDTH-1:0]EX_exc_now;
wire [79:0]EX_csr_access;
wire EX_ertn_flush;
wire EX_res_from_csr;
wire EX_is_rdcntvl_w;
wire EX_is_rdcntvh_w;
wire EX_is_rdcntid;
wire EX_to_MEM_req;
assign {EX_alu_op,
        EX_alu_src1,
        EX_alu_src2,
        EX_gr_we,
        EX_mem_we,
        EX_dest,
        EX_rkd_value,
        EX_pc,
        EX_res_from_mem,
		EX_is_div_mod_s,
		EX_is_div_mod_u,
		EX_div_or_mod,
        EX_is_ld_b,
        EX_is_ld_h,
        EX_is_ld_hu,
        EX_is_ld_bu,
        EX_is_st_b,
        EX_is_st_h,
        EX_is_st_w,
		EX_exc_last,
		EX_csr_access,
		EX_ertn_flush,
		EX_res_from_csr,
		EX_is_rdcntvl_w,
		EX_is_rdcntvh_w
} = ID_to_EX_bus_reg;
wire is_rdcntv = EX_is_rdcntvl_w | EX_is_rdcntvh_w;
wire [31:0]rdcnv_result = {32{EX_is_rdcntvl_w}} & glob_cnt[31:0] |
                    {32{EX_is_rdcntvh_w}} & glob_cnt[63:32]; 
//可扩??
wire EX_is_ld_w = EX_res_from_mem && 
                ~(EX_is_ld_b | EX_is_ld_h | EX_is_ld_bu | EX_is_ld_hu);

wire exc_ale =
    (EX_is_ld_h  || EX_is_ld_hu || EX_is_st_h)  ? (ex_final_result[0] != 1'b0) :
    (EX_is_ld_w  || EX_is_st_w )                ? (|ex_final_result[1:0]) :
    1'b0;

//ALE发生时，BADV记录出错地址，故res_from_mem置为0,防止覆盖其???
wire res_from_mem = EX_res_from_mem & !exc_ale;
assign EX_to_MEM_bus = {res_from_mem,  
                       EX_gr_we       ,  
                       EX_dest        ,  
                       ex_final_result,  
                       EX_pc          ,
                       EX_is_ld_b     ,
                       EX_is_ld_h     ,
                       EX_is_ld_bu    ,
                       EX_is_ld_hu    ,
					   EX_exc_now,
					   EX_csr_access,
					   EX_ertn_flush,
					   EX_res_from_csr,
                       EX_to_MEM_req
                      };
assign EX_to_ID_forward = {EX_gr_we,
                         EX_to_ID_dest,
                         ex_final_result,
						 EX_res_from_csr
                        };

assign EX_exc_now = |EX_exc_last ?  EX_exc_last:
					{ {(`EXC_WIDTH-`EXC_ALE-1){1'b0}}, exc_ale, {`EXC_ALE{1'b0}} };

assign EX_ready_go    = (is_div & EX_valid) ? div_done : 
                        data_sram_req ? data_sram_addr_ok :
                        1'b1;

assign EX_allow     = !EX_valid || EX_ready_go && MEM_allow;
assign EX_to_MEM_valid =  EX_valid && EX_ready_go;
always @(posedge clk) begin
    if (reset) begin
        EX_valid <= 1'b0;
        ID_to_EX_bus_reg <= {`ID2EX_BUS_LEN{1'b0}};
    end
    else if (EX_allow) begin
        EX_valid <= ID_to_EX_valid;
        if (ID_to_EX_valid)
            ID_to_EX_bus_reg <= ID_to_EX_bus;
    end
end

assign  EX_to_ID_load_up = EX_valid & EX_res_from_mem & !exc_ale;
alu u_alu(
    .alu_op     (EX_alu_op    ),
    .alu_src1   (EX_alu_src1  ),
    .alu_src2   (EX_alu_src2  ),
    .alu_result (alu_result)
    );

divider my_divider(
	.clk(clk),
	.rst(reset),
	.src1(EX_alu_src1),
	.src2(EX_alu_src2),
	.is_div_mod_s(EX_is_div_mod_s),
	.is_div_mod_u(EX_is_div_mod_u),
	.div_or_mod(EX_div_or_mod),
    .valid(ID_to_EX_valid),
	.div_result(div_result),
	.div_done(div_done)
);
assign is_div = (EX_is_div_mod_s | EX_is_div_mod_u) & EX_valid;
assign ex_final_result = is_div ? div_result :
							is_rdcntv ? rdcnv_result:
							alu_result;
assign EX_to_ID_dest = EX_dest & {5{EX_valid}};

assign data_sram_wstrb  =    EX_is_st_b ? 
                            (ex_final_result[1:0] == 2'b00) ? 4'b0001 :
                            (ex_final_result[1:0] == 2'b01) ? 4'b0010 :
                            (ex_final_result[1:0] == 2'b10) ? 4'b0100 :
                            4'b1000 :
                        EX_is_st_h ?
                            (ex_final_result[1] == 1'b0)    ? 4'b0011 :
                            4'b1100 :
                        4'b1111;

assign data_sram_size   =   {2{EX_is_st_b}} & 2'b0 
                            | {2{EX_is_st_h}} & 2'b1 
                            | {2{EX_is_st_w}} & 2'd2;
wire EX_has_exc = has_exc | (|EX_exc_now);
assign data_sram_wr     =   EX_mem_we;
assign EX_to_MEM_req = ((EX_mem_we | EX_res_from_mem) & EX_valid & ~has_ertn & ~exc_ale & ~EX_has_exc);
assign data_sram_req    = ((EX_mem_we | EX_res_from_mem) & EX_valid & ~has_ertn & ~exc_ale & ~EX_has_exc) & MEM_allow;
// assign data_sram_we    = {4{EX_mem_we && EX_valid && ~EX_has_exc}} & write_strb;
assign data_sram_addr  = ex_final_result;
assign data_sram_wdata = EX_is_st_b ? {4{EX_rkd_value[7:0]}} :
                         EX_is_st_h ? {2{EX_rkd_value[15:0]}} :
                         EX_rkd_value;
endmodule
