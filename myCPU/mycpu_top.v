`include "defines.vh"

module mycpu_top(
    input  wire                 aclk,
    input  wire                 aresetn,
    // read request
    output wire  [3:0]          arid      ,
    output wire  [31:0]         araddr    ,
    output wire  [7:0]          arlen     ,
    output wire  [2:0]          arsize    ,
    output wire  [1:0]          arburst   ,
    output wire  [1:0]          arlock    ,
    output wire  [3:0]          arcache   ,
    output wire  [2:0]          arprot    ,
    output wire                 arvalid   ,
    input wire                  arready   ,
    // read respond
    input wire  [3:0]           rid       ,
    input wire  [31:0]          rdata     ,
    input wire  [1:0]           rresp     ,
    input wire                  rlast     ,
    input wire                  rvalid    ,
    output wire                 rready    ,
    // write request
    output wire [3:0]           awid      ,
    output wire [31:0]          awaddr    ,
    output wire [7:0]           awlen     ,
    output wire [2:0]           awsize    ,
    output wire [1:0]           awburst   ,
    output wire [1:0]           awlock    ,
    output wire [3:0]           awcache   ,
    output wire [2:0]           awprot    ,
    output wire                 awvalid   ,
    input wire                  awready   ,
    // write data
    output wire [3:0]           wid       ,
    output wire [31:0]          wdata     ,
    output wire [3:0]           wstrb     ,
    output wire                 wlast     ,
    output wire                 wvalid    ,
    input wire                  wready    ,
    // write respond
    input wire   [3:0]           bid       ,
    input wire   [1:0]           bresp     ,
    input wire                  bvalid    ,
    output wire                 bready    ,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);



reg resetn_r1, resetn_r2;
always @(posedge aclk or negedge aresetn) begin
  if(!aresetn) begin
    resetn_r1 <= 1'b0;
    resetn_r2 <= 1'b0;
  end else begin
    resetn_r1 <= 1'b1;
    resetn_r2 <= resetn_r1;
  end
end

wire resetn_sync = resetn_r2;   // 低有效，异步拉低/同步释放
wire reset_sync  = ~resetn_sync; // 高有效




wire         ID_allow;
wire         EX_allow;
wire         MEM_allow;
wire         WB_allow;
wire         IF_to_ID_valid;
wire         ID_to_EX_valid;
wire         EX_to_MEM_valid;
wire         MEM_to_WB_valid;
wire [`IF2ID_BUS_LEN - 1:0] IF_to_ID_bus;
wire [`ID2EX_BUS_LEN - 1:0] ID_to_EX_bus;
wire [`EX2MEM_BUS_LEN - 1:0] EX_to_MEM_bus;
wire [`MEM2WB_BUS_LEN - 1:0] MEM_to_WB_bus;
wire [`WB2ID_BUS_LEN- 1:0] WB_to_ID_bus;
wire [`ID2IF_BUS_LEN - 1:0] ID_to_IF_bus;
wire [`MEM_BYPASS_LEN - 1:0] MEM_to_ID_forward;
wire [`WB_BYPASS_LEN - 1:0] WB_to_ID_forward;
wire [`EX_BYPASS_LEN - 1:0] EX_to_ID_forward;
wire      EX_to_ID_load_up;
wire [`WB2CSR_BUS_LEN-1:0] WB2CSR_bus;
wire [79:0] WB_csr_access;
wire [31:0] csr_rvalue;
wire MEM_ertn_flush = MEM_to_WB_bus[1];
wire ertn_flush = WB2CSR_bus[80];
wire MEM_ex = |MEM_to_WB_bus[97:82];
wire wb_ex = WB2CSR_bus[79];
wire has_exc = MEM_ex  | wb_ex;
wire [31:0]ex_entry;
wire [31:0]era_pc;
wire has_int;
wire [7:0]hw_int_in = 8'b0;
wire [31:0]coreid_in = 32'b0;

// task 18
// TLB
// search port 0 (for fetch)
wire [              18:0] s0_vppn;
wire                      s0_va_bit12;
wire [               9:0] s0_asid;
wire                      s0_found;
wire [               3:0] s0_index;
wire [              19:0] s0_ppn;
wire [               5:0] s0_ps;
wire [               1:0] s0_plv;
wire [               1:0] s0_mat;
wire                      s0_d;
wire                      s0_v;
    
// search port 1 (for load/store)
wire [              18:0] s1_vppn;
wire                      s1_va_bit12;
wire [               9:0] s1_asid;
wire                      s1_found;
wire [               3:0] s1_index;
wire [              19:0] s1_ppn;
wire [               5:0] s1_ps;
wire [               1:0] s1_plv;
wire [               1:0] s1_mat;
wire                      s1_d;
wire                      s1_v;

// invtlb opcode
wire                      invtlb_valid;
wire  [              4:0] invtlb_op;

wire                      inst_wb_tlbfill;

// write port
wire                      tlbwe; //w(rite) e(nable)
wire [               3:0] csr_tlbidx_index;
wire                      w_e;
wire [              18:0] tlbehi_vppn_fromCSR;
wire [               5:0] w_ps;
wire [               9:0] asid_fromCSR;
wire                      w_g;

wire [              19:0] w_ppn0;
wire [               1:0] w_plv0;
wire [               1:0] w_mat0;
wire                      w_d0;
wire                      w_v0;

wire [              19:0] w_ppn1;
wire [               1:0] w_plv1;
wire [               1:0] w_mat1;
wire                      w_d1;
wire                      w_v1;
// read port
wire                      r_e;
wire [              18:0] r_vppn;
wire [               5:0] r_ps;
wire [               9:0] r_asid;
wire                      r_g;

wire [              19:0] r_ppn0;
wire [               1:0] r_plv0;
wire [               1:0] r_mat0;
wire                      r_d0;
wire                      r_v0;

wire [              19:0] r_ppn1;
wire [               1:0] r_plv1;
wire [               1:0] r_mat1;
wire                      r_d1;
wire                      r_v;

wire wb_refetch_flush;
wire [31:0] ertnentry_refetchtarget = ertn_flush ? era_pc : debug_wb_pc + 32'd4;
wire                      inst_wb_tlbsrch;
wire                      wb_tlbsrch_found;
wire [               3:0]    wb_tlbsrch_idxgot;
wire                      inst_wb_tlbrd;
wire [15:0] EX_tlb_stall_bus;
wire [15:0] MEM_tlb_stall_bus;

// task 19
wire [2:0] csr_dmw0_pseg;
wire [2:0] csr_dmw0_vseg;
wire [2:0] csr_dmw1_pseg;
wire [2:0] csr_dmw1_vseg;
wire       csr_dmw0_plv0;
wire       csr_dmw0_plv3;
wire       csr_dmw1_plv0;
wire       csr_dmw1_plv3;
wire       csr_direct_addr;
wire [1:0] crmd_plv_fromCSR;

wire       exc_now_fetch;
wire       wb_ex_e;


wire [31:0] inst_addr_vrtl;
wire        icache_rd_req;
wire [ 2:0] icache_rd_type;
wire [31:0] icache_rd_addr;
wire        icache_rd_rdy;
wire        icache_ret_valid;
wire        icache_ret_last;
wire [31:0] icache_ret_data;
wire        icache_wr_req = 1'b0;
wire [ 2:0] icache_wr_type;
wire [31:0] icache_wr_addr;
wire [ 3:0] icache_wr_wstrb;
wire [127:0]icache_wr_data;
wire        icache_wr_rdy = 1'b1;

wire [31:0] data_addr_vrtl;
wire        dcache_rd_req;
wire [ 2:0] dcache_rd_type;
wire [31:0] dcache_rd_addr;
wire        dcache_rd_rdy;
wire        dcache_ret_valid;
wire        dcache_ret_last;
wire [31:0] dcache_ret_data;

//dcache write channel
wire        dcache_wr_req;
wire [ 2:0] dcache_wr_type;
wire [31:0] dcache_wr_addr;
wire [ 3:0] dcache_wr_wstrb;
wire[127:0] dcache_wr_data;
wire        dcache_wr_rdy;

// task 23
wire icache_store_tag;
wire icache_Index_Inv;
wire icache_Hit_Inv;
wire dcache_store_tag;
wire dcache_Index_Inv;
wire dcache_Hit_Inv;
wire [31:0] cache_va;
wire icacop_ok;
wire dcacop_ok;
wire cacop_ok;

wire icache_cacop;
wire dcache_cacop;

assign icache_cacop = icache_store_tag | icache_Index_Inv | icache_Hit_Inv;
assign dcache_cacop = dcache_store_tag | dcache_Index_Inv | dcache_Hit_Inv;
assign cacop_ok = icache_cacop & icacop_ok | dcache_cacop & dcacop_ok;

wire       exc_now_cacop;


wire inst_sram_req;
wire inst_sram_wr;
wire [1:0]  inst_sram_size;
wire [3:0]  inst_sram_wstrb;
wire[31:0] inst_sram_addr;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire[31:0] inst_sram_wdata;
wire[31:0] inst_sram_rdata;
    // data sram interface
wire        data_sram_req;
wire        data_sram_wr;
wire [1:0]  data_sram_size;
wire [3:0]  data_sram_wstrb;
    // output wire       data_sram_en,
wire[31:0] data_sram_addr;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire[31:0] data_sram_wdata;
wire[31:0] data_sram_rdata;

wire [1:0]  csr_crmd_datm;
wire [1:0]  csr_dmw1_mat;
wire [1:0]  csr_dmw0_mat;
wire [1:0] datm;

//task13 - counter
reg [63:0]stable_counter;
always @(posedge aclk ) 
begin
	if (reset_sync)
		stable_counter <= 64'b0;
	else 
		stable_counter <= stable_counter + 1'b1;
end
wire [63:0]glob_cnt = stable_counter ;
csr my_csr(
	.clk(aclk),
	.reset(reset_sync),
	.WB_csr_access(WB_csr_access),
	.csr_rvalue(csr_rvalue),
	.hw_int_in(hw_int_in),
	.ex_entry(ex_entry),
	.era_pc(era_pc),
	.has_int(has_int),
	.WB2CSR_bus(WB2CSR_bus),
	.coreid_in(coreid_in),
    // task 18
    .csr_asid_asid   (asid_fromCSR),
    .csr_tlbehi_vppn (tlbehi_vppn_fromCSR),
    .csr_tlbidx_index(csr_tlbidx_index),

    .tlbsrch_we        (inst_wb_tlbsrch),
    .tlbsrch_hit       (wb_tlbsrch_found),
    .tlbsrch_hit_index (wb_tlbsrch_idxgot),
    .tlbrd_we          (inst_wb_tlbrd),

    .r_tlb_e         (r_e),
    .r_tlb_ps        (r_ps),
    .r_tlb_vppn      (r_vppn),
    .r_tlb_asid      (r_asid),
    .r_tlb_g         (r_g),
    .r_tlb_ppn0      (r_ppn0),
    .r_tlb_plv0      (r_plv0),
    .r_tlb_mat0      (r_mat0),
    .r_tlb_d0        (r_d0),
    .r_tlb_v0        (r_v0),
    .r_tlb_ppn1      (r_ppn1),
    .r_tlb_plv1      (r_plv1),
    .r_tlb_mat1      (r_mat1),
    .r_tlb_d1        (r_d1),
    .r_tlb_v1        (r_v1),

    .w_tlb_e         (w_e),
    .w_tlb_ps        (w_ps),
    .w_tlb_vppn      (tlbehi_vppn_fromCSR),
    .w_tlb_asid      (asid_fromCSR),
    .w_tlb_g         (w_g),
    .w_tlb_ppn0      (w_ppn0),
    .w_tlb_plv0      (w_plv0),
    .w_tlb_mat0      (w_mat0),
    .w_tlb_d0        (w_d0),
    .w_tlb_v0        (w_v0),
    .w_tlb_ppn1      (w_ppn1),
    .w_tlb_plv1      (w_plv1),
    .w_tlb_mat1      (w_mat1),
    .w_tlb_d1        (w_d1),
    .w_tlb_v1        (w_v1),
    // task 19
    .csr_crmd_plv (crmd_plv_fromCSR),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_direct_addr(csr_direct_addr),
    .exc_now_fetch(exc_now_fetch),
    .csr_dmw1_mat(csr_dmw1_mat),
    .csr_dmw0_mat(csr_dmw0_mat),
    .csr_crmd_datm(csr_crmd_datm),
    // task 23
    .exc_now_cacop(exc_now_cacop)
);


// IF stage
if_stage if_stage(
    .clk            (aclk),
    .reset          (reset_sync),
    .ID_allow       (ID_allow),
    .ID_to_IF_bus   (ID_to_IF_bus),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus   (IF_to_ID_bus),
	.wb_ex(wb_ex_e),
	.ex_entry(ex_entry),
	.ertn_flush(ertn_flush || wb_refetch_flush),
	.era_pc(ertnentry_refetchtarget),
    .inst_sram_req  (inst_sram_req),
    .inst_sram_wr   (inst_sram_wr),
    .inst_sram_size (inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .s0_vppn    (s0_vppn   ),
    .s0_va_bit12(s0_va_bit12),
    .s0_found   (s0_found  ),
    .s0_index   (s0_index  ),
    .s0_ppn     (s0_ppn    ),
    .s0_ps      (s0_ps     ),
    .s0_plv     (s0_plv    ),
    .s0_v       (s0_v      ),
    .crmd_plv_fromCSR(crmd_plv_fromCSR),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_direct_addr(csr_direct_addr),
    .inst_addr_vrtl(inst_addr_vrtl)
);
// ID stage
id_stage id_stage(
    .clk            (aclk),
    .reset          (reset_sync||wb_ex||ertn_flush||wb_refetch_flush),
    .EX_allow       (EX_allow),
    .ID_allow       (ID_allow),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus   (IF_to_ID_bus),
    .ID_to_EX_valid (ID_to_EX_valid),
    .EX_to_ID_forward(EX_to_ID_forward),
    .MEM_to_ID_forward(MEM_to_ID_forward),
    .WB_to_ID_forward(WB_to_ID_forward),
    .ID_to_EX_bus   (ID_to_EX_bus),
    .ID_to_IF_bus   (ID_to_IF_bus),
    .WB_to_ID_bus   (WB_to_ID_bus),
    .EX_to_ID_load_up(EX_to_ID_load_up),
	.has_int(has_int),
    .EX_tlb_stall_bus(EX_tlb_stall_bus),
    .MEM_tlb_stall_bus(MEM_tlb_stall_bus)
);
// EX stage
ex_stage ex_stage(
    .clk            (aclk),
    .reset          (reset_sync||wb_ex||ertn_flush||wb_refetch_flush),
    .MEM_allow      (MEM_allow),
    .EX_allow       (EX_allow),
    .ID_to_EX_valid (ID_to_EX_valid),
    .ID_to_EX_bus   (ID_to_EX_bus),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .EX_to_MEM_bus  (EX_to_MEM_bus),
    .EX_to_ID_forward(EX_to_ID_forward),
    .EX_to_ID_load_up(EX_to_ID_load_up),
	.has_exc(has_exc),
	.has_ertn(MEM_ertn_flush||ertn_flush||wb_refetch_flush),
	.glob_cnt(glob_cnt),
    .data_sram_req  (data_sram_req),
    .data_sram_wr   (data_sram_wr),
    .data_sram_size (data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    // task 18
    .invtlb_op   (invtlb_op),
    .inst_invtlb (invtlb_valid),
    .s1_vppn     (s1_vppn),
    .s1_va_bit12 (s1_va_bit12),
    .s1_asid     (s1_asid),
    .s1_found    (s1_found  ),
    .s1_index    (s1_index  ),
    .s1_ppn      (s1_ppn    ),
    .s1_ps       (s1_ps     ),
    .s1_plv      (s1_plv    ),
    .s1_mat      (s1_mat    ),
    .s1_d        (s1_d      ),
    .s1_v        (s1_v      ),
    .tlbehi_vppn_fromCSR(tlbehi_vppn_fromCSR),
    .asid_fromCSR(asid_fromCSR),
    .EX_tlb_stall_bus(EX_tlb_stall_bus),
    // task 19
    .crmd_plv_fromCSR(crmd_plv_fromCSR),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_direct_addr(csr_direct_addr),
    .csr_dmw1_mat(csr_dmw1_mat),
    .csr_dmw0_mat(csr_dmw0_mat),
    .datm(datm),
    .wb_ex_e(wb_ex_e),
    .vtl_addr(data_addr_vrtl),
    .csr_crmd_datm(csr_crmd_datm),
    // task 23
    .icache_store_tag(icache_store_tag),
    .icache_Index_Inv(icache_Index_Inv),
    .icache_Hit_Inv(icache_Hit_Inv),
    .dcache_store_tag(dcache_store_tag),
    .dcache_Index_Inv(dcache_Index_Inv),
    .dcache_Hit_Inv(dcache_Hit_Inv),
    .cache_va(cache_va),
    .cacop_ok(cacop_ok)
);
// MEM stage
mem_stage mem_stage(
    .clk             (aclk),
    .reset           (reset_sync||wb_ex||ertn_flush||wb_refetch_flush),
    .WB_allow        (WB_allow),
    .MEM_allow       (MEM_allow),
    .EX_to_MEM_valid (EX_to_MEM_valid),
    .EX_to_MEM_bus   (EX_to_MEM_bus),
    .MEM_to_WB_valid (MEM_to_WB_valid),
    .MEM_to_WB_bus   (MEM_to_WB_bus),
    .MEM_to_ID_forward (MEM_to_ID_forward),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .MEM_tlb_stall_bus(MEM_tlb_stall_bus)
);
// WB stage
wb_stage wb_stage(
    .clk                (aclk),
    .reset              (reset_sync||wb_ex||ertn_flush),
    .WB_allow           (WB_allow),
    .MEM_to_WB_valid    (MEM_to_WB_valid),
    .MEM_to_WB_bus      (MEM_to_WB_bus),
    .WB_to_ID_bus       (WB_to_ID_bus),
    .WB_to_ID_forward   (WB_to_ID_forward),
	.WB2CSR_bus			(WB2CSR_bus),
	.WB_csr_access		(WB_csr_access),
	.csr_rvalue			(csr_rvalue),
    // task 18
    .inst_wb_tlbfill(inst_wb_tlbfill),
    .inst_wb_tlbsrch(inst_wb_tlbsrch),
    .tlbwe      (tlbwe),
    .inst_wb_tlbrd(inst_wb_tlbrd),
    .wb_tlbsrch_found(wb_tlbsrch_found),
    .wb_tlbsrch_idxgot(wb_tlbsrch_idxgot),
    .WB_refetch_flush(wb_refetch_flush),
    // task 19
    .WB_exc_fetch(exc_now_fetch),
    .wb_ex_e(wb_ex_e),
    //trace debug interface
    .debug_wb_pc        (debug_wb_pc),
    .debug_wb_rf_we     (debug_wb_rf_we),
    .debug_wb_rf_wnum   (debug_wb_rf_wnum),
    .debug_wb_rf_wdata  (debug_wb_rf_wdata),
    // task 23
    .exc_now_cacop(exc_now_cacop)

);

sram_axi_bridge sram_axi_bridge(
    .aclk               (aclk               ),
    .aresetn            (resetn_sync        ),

    .arid               (arid               ),
    .araddr             (araddr             ),
    .arlen              (arlen              ),
    .arsize             (arsize             ),
    .arburst            (arburst            ),
    .arlock             (arlock             ),
    .arcache            (arcache            ),
    .arprot             (arprot             ),
    .arvalid            (arvalid            ),
    .arready            (arready            ),

    .rid                (rid                ),
    .rdata              (rdata              ),
    .rvalid             (rvalid             ),
    .rlast              (rlast              ),
    .rresp              (rresp              ),
    .rready             (rready             ),

    .awid               (awid               ),
    .awaddr             (awaddr             ),
    .awlen              (awlen              ),
    .awsize             (awsize             ),
    .awburst            (awburst            ),
    .awlock             (awlock             ),
    .awcache            (awcache            ),
    .awprot             (awprot             ),
    .awvalid            (awvalid            ),
    .awready            (awready            ),

    .wid                (wid                ),
    .wdata              (wdata              ),
    .wstrb              (wstrb              ),
    .wlast              (wlast              ),
    .wvalid             (wvalid             ),
    .wready             (wready             ),

    .bid                (bid                ),
    .bvalid             (bvalid             ),
    .bresp              (bresp              ),
    .bready             (bready             ),

    .icache_rd_req      (icache_rd_req      ),
    .icache_rd_type     (icache_rd_type     ),
    .icache_rd_addr     (icache_rd_addr     ),
    .icache_rd_rdy      (icache_rd_rdy      ),
    .icache_ret_valid   (icache_ret_valid   ),
    .icache_ret_last    (icache_ret_last    ),
    .icache_ret_data    (icache_ret_data    ),

    .dcache_rd_req      (dcache_rd_req      ),
    .dcache_rd_type     (dcache_rd_type     ),
    .dcache_rd_addr     (dcache_rd_addr     ),
    .dcache_rd_rdy      (dcache_rd_rdy      ),
    .dcache_ret_valid   (dcache_ret_valid   ),
    .dcache_ret_last    (dcache_ret_last    ),
    .dcache_ret_data    (dcache_ret_data    ),

    .dcache_wr_req      (dcache_wr_req      ),
    .dcache_wr_type     (dcache_wr_type     ),
    .dcache_wr_addr     (dcache_wr_addr     ),
    .dcache_wr_wstrb    (dcache_wr_wstrb    ),
    .dcache_wr_data     (dcache_wr_data     ),
    .dcache_wr_rdy      (dcache_wr_rdy      )
);


tlb tlb(
    .clk        (aclk      ),
    .resetn     (resetn_sync    ),

    .s0_vppn    (s0_vppn   ),
    .s0_va_bit12(s0_va_bit12),
    .s0_asid    (asid_fromCSR   ),
    .s0_found   (s0_found  ),
    .s0_index   (s0_index  ),
    .s0_ppn     (s0_ppn    ),
    .s0_ps      (s0_ps     ),
    .s0_plv     (s0_plv    ),
    .s0_mat     (s0_mat    ),
    .s0_d       (s0_d      ),
    .s0_v       (s0_v      ),

    .s1_vppn    (s1_vppn   ),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid    (s1_asid   ),
    .s1_found   (s1_found  ),
    .s1_index   (s1_index  ),
    .s1_ppn     (s1_ppn    ),
    .s1_ps      (s1_ps     ),
    .s1_plv     (s1_plv    ),
    .s1_mat     (s1_mat    ),
    .s1_d       (s1_d      ),
    .s1_v       (s1_v      ),

    .invtlb_valid(invtlb_valid),
    .invtlb_op  (invtlb_op ),

    .inst_wb_tlbfill(inst_wb_tlbfill),

    .we         (tlbwe     ),
    .w_index    (csr_tlbidx_index),
    .w_e        (w_e       ),
    .w_vppn     (tlbehi_vppn_fromCSR),
    .w_ps       (w_ps      ),
    .w_asid     (asid_fromCSR),
    .w_g        (w_g       ),

    .w_ppn0     (w_ppn0    ),
    .w_plv0     (w_plv0    ),
    .w_mat0     (w_mat0    ),
    .w_d0       (w_d0      ),
    .w_v0       (w_v0      ),

    .w_ppn1     (w_ppn1    ),
    .w_plv1     (w_plv1    ),
    .w_mat1     (w_mat1    ),
    .w_d1       (w_d1      ),
    .w_v1       (w_v1      ),

    .r_index    (csr_tlbidx_index),
    .r_e        (r_e       ),
    .r_vppn     (r_vppn    ),
    .r_ps       (r_ps      ),
    .r_asid     (r_asid    ),
    .r_g        (r_g       ),

    .r_ppn0     (r_ppn0    ),
    .r_plv0     (r_plv0    ),
    .r_mat0     (r_mat0    ),
    .r_d0       (r_d0      ),
    .r_v0       (r_v0      ),

    .r_ppn1     (r_ppn1    ),
    .r_plv1     (r_plv1    ),
    .r_mat1     (r_mat1    ),
    .r_d1       (r_d1      ),
    .r_v1       (r_v1      )
);

cache Icache(
    .clk    (aclk                       ),
    .resetn (resetn_sync                ),
    .valid  (inst_sram_req & ~icache_Hit_Inv   ),
    .op     (inst_sram_wr               ),
    .index  (inst_addr_vrtl[11:4]       ),
    .tag    (inst_sram_addr[31:12]      ),
    .offset (inst_addr_vrtl[3:0]        ),
    .wstrb  (inst_sram_wstrb            ),
    .wdata  (inst_sram_wdata            ),
    .addr_ok(inst_sram_addr_ok          ),  
    .data_ok(inst_sram_data_ok          ),
    .rdata  (inst_sram_rdata            ),

    .rd_req (icache_rd_req              ),
    .rd_type(icache_rd_type             ),
    .rd_addr(icache_rd_addr             ),
    .rd_rdy   (icache_rd_rdy            ),
    .ret_valid(icache_ret_valid         ),
    .ret_last (icache_ret_last          ),
    .ret_data (icache_ret_data          ),

    .wr_req (icache_wr_req              ),
    .wr_type(icache_wr_type             ),
    .wr_addr(icache_wr_addr             ),
    .wr_wstrb(icache_wr_wstrb             ),
    .wr_data(icache_wr_data             ),
    .datm(2'b01                         ),
    .wr_rdy (icache_wr_rdy              ),
    
    // task 23
    .cache_store_tag (icache_store_tag),
    .cache_Index_Inv (icache_Index_Inv),
    .cache_Hit_Inv (icache_Hit_Inv),
    .cacop_va (cache_va),
    .cacop_ok (icacop_ok)
);

cache Dcache(
    .clk    (aclk                       ),
    .resetn (resetn_sync               ),
    .valid  (data_sram_req              ),
    .op     (data_sram_wr               ),
    .index  (data_addr_vrtl[11:4]       ),
    .tag    (data_sram_addr[31:12]      ),
    .offset (data_addr_vrtl[3:0]        ),
    .wstrb  (data_sram_wstrb            ),
    .wdata  (data_sram_wdata            ),
    .addr_ok(data_sram_addr_ok          ),
    .data_ok(data_sram_data_ok          ),
    .rdata  (data_sram_rdata            ),

    .rd_req (dcache_rd_req              ),
    .rd_type(dcache_rd_type             ),
    .rd_addr(dcache_rd_addr             ),
    .rd_rdy   (dcache_rd_rdy            ),
    .ret_valid(dcache_ret_valid         ),
    .ret_last (dcache_ret_last          ),
    .ret_data (dcache_ret_data          ),

    .wr_req (dcache_wr_req              ),
    .wr_type(dcache_wr_type             ),
    .wr_addr(dcache_wr_addr             ),
    .wr_wstrb(dcache_wr_wstrb            ),
    .wr_data(dcache_wr_data             ),
    .datm   (datm                       ),
    .wr_rdy (dcache_wr_rdy              ),

    // task 23
    .cache_store_tag(dcache_store_tag),
    .cache_Index_Inv(dcache_Index_Inv),
    .cache_Hit_Inv(dcache_Hit_Inv),
    .cacop_va(cache_va),
    .cacop_ok(dcacop_ok)
);

endmodule
