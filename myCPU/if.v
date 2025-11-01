`include "defines.vh"
module if_stage(
    input     wire                      clk         ,
    input     wire                      reset       ,
    input     wire                      ID_allow    ,
    input  wire [`ID2IF_BUS_LEN -1:0] ID_to_IF_bus         ,
    output      wire                    IF_to_ID_valid ,
    output wire [`IF2ID_BUS_LEN -1:0] IF_to_ID_bus   ,
    // inst sram interface
    output wire        inst_sram_en   ,
    output wire [ 3:0] inst_sram_we  ,
    output wire [31:0] inst_sram_addr ,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
	//csr
	input wire wb_ex,
	input wire [31:0]ex_entry,
	input wire ertn_flush,
	input wire [31:0]era_pc
);
wire         br_taken;
wire [ 31:0] br_target;
reg         IF_valid;
wire        IF_ready_go;
wire        IF_allow;
wire        pre_IF_valid;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire [`EXC_WIDTH-1:0]exc_last;
wire [`EXC_WIDTH-1:0]exc_now;


reg exc_adef;

always @(posedge clk) begin
    if (reset)
        exc_adef <= 1'b0;
    else
        exc_adef <= (nextpc[1:0] != 2'b00);
end
assign exc_last = 16'b0;
assign exc_now = exc_last | { {(`EXC_WIDTH-`EXC_ADEF-1){1'b0}}, exc_adef, {`EXC_ADEF{1'b0}} };

assign {br_taken, br_target} = ID_to_IF_bus;

wire [31:0] IF_inst;
reg  [31:0] IF_pc;
assign IF_to_ID_bus = {exc_now,
						IF_inst ,
                    	IF_pc   };

// pre-IF stage

assign pre_IF_valid  = ~reset;
assign seq_pc       = IF_pc + 3'h4;
assign nextpc       = (ertn_flush) ? era_pc:
					(wb_ex) ? ex_entry:
					(br_taken) ? br_target : seq_pc; 

// IF stage
assign IF_ready_go    = ~br_taken;   
assign IF_allow     = !IF_valid || IF_ready_go && ID_allow;  
assign IF_to_ID_valid =  IF_valid && IF_ready_go;   
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
    else if ((pre_IF_valid && (IF_allow||br_taken))||wb_ex||ertn_flush ) begin
        IF_pc <= nextpc;
    end
end



assign inst_sram_en    =( pre_IF_valid && (IF_allow || br_taken))||wb_ex||ertn_flush ;
assign inst_sram_we   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign IF_inst         = inst_sram_rdata;

endmodule
