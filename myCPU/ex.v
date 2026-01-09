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
	input wire has_ertn, //MEM,WB级是ertn,也不能写入mem,因为要清空流水线
	input wire [63:0]glob_cnt,
    // task 18
    output wire [ 4:0] invtlb_op,
    output wire        inst_invtlb,
    output wire [18:0] s1_vppn,
    output wire        s1_va_bit12,
    output wire [ 9:0] s1_asid,

    input         s1_found,
    input  [ 3:0] s1_index,
    input  [19:0] s1_ppn,
    input  [ 5:0] s1_ps,
    input  [ 1:0] s1_plv,
    input  [ 1:0] s1_mat,
    input         s1_d,
    input         s1_v,

    input  wire [18:0] tlbehi_vppn_fromCSR,
    input  wire [ 9:0] asid_fromCSR,
    output wire [16:0] EX_tlb_stall_bus,

    // task 19
    input  wire [ 1:0] crmd_plv_fromCSR,
    // DMW0
    input  wire        csr_dmw0_plv0,
    input  wire        csr_dmw0_plv3,
    input  wire [ 2:0] csr_dmw0_pseg,
    input  wire [ 2:0] csr_dmw0_vseg,
    input  wire [ 1:0] csr_dmw0_mat,
    // DMW1
    input  wire        csr_dmw1_plv0,
    input  wire        csr_dmw1_plv3,
    input  wire [ 2:0] csr_dmw1_pseg,
    input  wire [ 2:0] csr_dmw1_vseg,
    input  wire [ 1:0] csr_dmw1_mat,
    // direct addr
    input  wire        csr_direct_addr,
    input  wire        wb_ex_e,
    output wire [31:0] vtl_addr,
    input wire [1:0]  csr_crmd_datm,
    output wire [1:0] datm,
    // task 23
    output wire icache_store_tag,
    output wire icache_Index_Inv,
    output wire icache_Hit_Inv,
    output wire dcache_store_tag,
    output wire dcache_Index_Inv,
    output wire dcache_Hit_Inv,
    output wire [31:0] cache_va,
    input  wire cacop_ok
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
wire EX_to_ID_req;
wire [4:0] EX_to_ID_dest_dest;

// task 18
wire  [10:0] EX_tlb_bus;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        EX_refetch_flag;
wire [ 9:0] EX_to_MEM_tlb_bus;
//csr
wire [13:0] EX_csr_num;
wire        EX_csr_we;
wire [31:0] EX_csr_wmask;
wire [31:0] EX_csr_wvalue;
wire [78:0] EX_csr_access_b;

// task 19 - addr translation
wire        dmw0_hit;
wire        dmw1_hit;
wire [31:0] dmw0_paddr;
wire [31:0] dmw1_paddr;
wire [31:0] tlb_paddr ;

wire [31:0] vtl_addr;   // 虚拟地址
wire [31:0] phy_addr;   // 物理地址

wire [ 7:0] EX_tlb_exc;
wire [ 7:0] EX_exc_tlb   ;
wire [ 7:0] EX_to_MEM_exc_tlb;
wire        tlb_used  ; // 确实用到了TLB进行地址翻译
wire        isLoad ;
wire        isStore;

// task 23
wire        EX_cacop;
wire  [4:0] EX_cacop_code;

assign {EX_cacop,
        EX_cacop_code,
        EX_tlb_exc,
        EX_tlb_bus,
        EX_alu_op,
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

//ALE发生时，BADV记录出错地址，故res_from_mem置为0,防止覆盖其值
wire res_from_mem = EX_res_from_mem & !exc_ale;
assign EX_to_MEM_bus = {EX_cacop,
                        EX_to_MEM_exc_tlb,
                        EX_to_MEM_tlb_bus,
                        res_from_mem,  
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
						 EX_res_from_csr,
                         EX_to_ID_req,
                         EX_to_ID_dest_dest
                        };

/* assign EX_exc_now = |EX_exc_last ?  EX_exc_last:
					{ {(`EXC_WIDTH-`EXC_ALE-1){1'b0}}, exc_ale, {`EXC_ALE{1'b0}} }; */

assign EX_exc_now = |EX_exc_last ?  EX_exc_last:
                    {1'b0, EX_exc_tlb[`EARRAY_TLBR_MEM], 6'b0, exc_ale, 2'b0, EX_exc_tlb[`EARRAY_PPI_MEM], EX_exc_tlb[`EARRAY_PME], 1'b0, EX_exc_tlb[`EARRAY_PIS], EX_exc_tlb[`EARRAY_PIL], 1'b0};

assign EX_ready_go    = EX_cacop ? cacop_ok :
                        (is_div & EX_valid) ? div_done : 
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
//req而且load
assign EX_to_ID_req = data_sram_req  && ~data_sram_wr;
assign is_div = (EX_is_div_mod_s | EX_is_div_mod_u) & EX_valid;
assign ex_final_result = is_div ? div_result :
                         is_rdcntv ? rdcnv_result:
                         alu_result;
assign EX_to_ID_dest = EX_dest & {5{EX_valid}};
assign EX_to_ID_dest_dest = EX_dest;
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
//基本上是data_sram_en的复用，现在loadstore都是精确异常
assign EX_to_MEM_req = ((EX_mem_we | EX_res_from_mem) & EX_valid & ~has_ertn & ~exc_ale & ~EX_has_exc);
assign data_sram_req    = ((EX_mem_we | EX_res_from_mem) & EX_valid & ~has_ertn & ~exc_ale & ~EX_has_exc);
// assign data_sram_we    = {4{EX_mem_we && EX_valid && ~EX_has_exc}} & write_strb;x
assign data_sram_addr  = phy_addr;
assign data_sram_wdata = EX_is_st_b ? {4{EX_rkd_value[7:0]}} :
                         EX_is_st_h ? {2{EX_rkd_value[15:0]}} :
                         EX_rkd_value;

// task 18
assign {EX_refetch_flag, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, invtlb_op} = EX_tlb_bus;
assign {s1_vppn, s1_va_bit12} = inst_invtlb ? EX_rkd_value[31:12] :
                                inst_tlbsrch ? {tlbehi_vppn_fromCSR, 1'b0} :
                                alu_result[31:12]; // Normal Load/Store translation, RESERVED for exp19

assign s1_asid       = inst_invtlb ?  EX_alu_src1[9:0] : asid_fromCSR; // alu src1 is rj value
assign EX_to_MEM_tlb_bus = {EX_refetch_flag, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, s1_found, s1_index};
assign EX_csr_access_b = {EX_csr_access[79:66], EX_csr_access[64:0]};
assign {EX_csr_num, EX_csr_we, EX_csr_wvalue, EX_csr_wmask} = EX_csr_access_b;
assign EX_tlb_stall_bus = {inst_tlbrd & EX_valid, EX_csr_we & EX_valid, EX_csr_num};

// task 19 - addr translation
assign vtl_addr = alu_result;
assign dmw0_hit  = (vtl_addr[31:29] == csr_dmw0_vseg) & (crmd_plv_fromCSR == 2'd0 & csr_dmw0_plv0 | crmd_plv_fromCSR == 2'd3 & csr_dmw0_plv3);
assign dmw1_hit  = (vtl_addr[31:29] == csr_dmw1_vseg) & (crmd_plv_fromCSR == 2'd0 & csr_dmw1_plv0 | crmd_plv_fromCSR == 2'd3 & csr_dmw1_plv3);
assign dmw0_paddr = {csr_dmw0_pseg, vtl_addr[28:0]};
assign dmw1_paddr = {csr_dmw1_pseg, vtl_addr[28:0]};
assign tlb_paddr  = (s1_ps == 6'd21) ? {s1_ppn[19:10], vtl_addr[21:0]} : {s1_ppn, vtl_addr[11:0]}; // depends on page size
assign phy_addr   = csr_direct_addr ? vtl_addr    :
                    dmw0_hit        ? dmw0_paddr  :
                    dmw1_hit        ? dmw1_paddr  :
                                      tlb_paddr   ;
assign tlb_used = (EX_res_from_mem | (|EX_mem_we) | EX_cacop & EX_cacop_code[4:3] == 2'b10) & ~wb_ex_e & ~(|EX_exc_last) & ~exc_ale //es_mem_req 
                    & (~csr_direct_addr & ~dmw0_hit & ~dmw1_hit);
assign isStore  = |EX_mem_we;
assign isLoad   = EX_res_from_mem;
assign {EX_exc_tlb[`EARRAY_PIF], EX_exc_tlb[`EARRAY_PPI_FETCH]} = 2'b0;
assign EX_exc_tlb[`EARRAY_TLBR_FETCH] = EX_valid & tlb_used & EX_cacop & (EX_cacop_code == 5'b10000) & !s1_found;
assign EX_exc_tlb[`EARRAY_TLBR_MEM] = EX_valid & (EX_res_from_mem | (EX_cacop & (EX_cacop_code == 5'b10001))) & tlb_used & !s1_found;
assign EX_exc_tlb[`EARRAY_PIL ] = EX_valid & tlb_used & (isLoad | EX_cacop)  & !EX_exc_tlb[`EARRAY_TLBR_MEM] & !s1_v;
assign EX_exc_tlb[`EARRAY_PIS ] = EX_valid & tlb_used & isStore & !EX_exc_tlb[`EARRAY_TLBR_MEM] & !s1_v;
assign EX_exc_tlb[`EARRAY_PPI_MEM] = EX_valid & tlb_used & (isLoad | isStore) & !EX_exc_tlb[`EARRAY_PIL] & !EX_exc_tlb[`EARRAY_PIS] & (crmd_plv_fromCSR > s1_plv) & !EX_exc_tlb[`EARRAY_TLBR_MEM];
assign EX_exc_tlb[`EARRAY_PME ] = EX_valid & tlb_used & isStore & !EX_exc_tlb[`EARRAY_PPI_MEM] & !s1_d & !EX_exc_tlb[`EARRAY_PPI_MEM] & !s1_d;
assign EX_to_MEM_exc_tlb = EX_tlb_exc | EX_exc_tlb;
assign datm       = csr_direct_addr ? csr_crmd_datm :
                    dmw0_hit        ? csr_dmw0_mat  :
                    dmw1_hit        ? csr_dmw1_mat  :
                                        s1_mat        ; 

// task 23
assign icache_store_tag = EX_cacop & (EX_cacop_code == 5'b00000) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign icache_Index_Inv = EX_cacop & (EX_cacop_code == 5'b01000) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign icache_Hit_Inv = EX_cacop & (EX_cacop_code == 5'b10000) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign dcache_store_tag = EX_cacop & (EX_cacop_code == 5'b00001) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign dcache_Index_Inv = EX_cacop & (EX_cacop_code == 5'b01001) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign dcache_Hit_Inv = EX_cacop & (EX_cacop_code == 5'b10001) & EX_valid & MEM_allow & ~wb_ex_e & ~has_exc & ~EX_exc_now;
assign cache_va = (icache_store_tag | icache_Index_Inv | dcache_store_tag | dcache_Index_Inv) ? vtl_addr :
                    ((icache_Hit_Inv | dcache_Hit_Inv) & ~(|EX_exc_tlb)) ? phy_addr :
                    32'b0;
                    
endmodule
