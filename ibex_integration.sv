import ibex_pkg::*;

module ibex_integration
#(
    parameter IBEX_RV32E        = 1,
    parameter IBEX_ICACHE       = 1
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         po_rst_ni,

    input  logic [31:0]                  boot_addr_i,

    // Instrcution IF
    output logic                         bus_instr_read,
    input logic                          bus_instr_busy,
    input logic                          bus_instr_rvalid,
    output logic [31:0]                  bus_instr_addr,
    input logic [31:0]                   bus_instr_rdata,

    // Data IF
    output logic                         bus_data_read,
    input logic                          bus_data_busy,
    input logic                          bus_data_rvalid,
    output logic [31:0]                  bus_data_addr,
    output logic                         bus_data_write,
    output logic [3:0]                   bus_data_be,
    input logic [31:0]                   bus_data_rdata,
    output logic [31:0]                  bus_data_wdata,
    input logic [1:0]                    bus_data_resp,
    input logic                          bus_data_wrespvalid,

    // Interrupt inputs
    input  logic                         irq_software_i,
    input  logic                         irq_timer_i,
    input  logic                         irq_external_i,
    input  logic [14:0]                  irq_fast_i,
    input  logic                         irq_nm_i,

    // CPU Control Signals
    //input  ibex_mubi_t                   fetch_enable_i,
    output logic                         core_sleep_o,

    // Avalon slave for DM
    input [31:0]                         dm_avalon_s_writedata,
    output [31:0]                        dm_avalon_s_readdata,
    input [11:0]                         dm_avalon_s_address,
    input [3:0]                          dm_avalon_s_byteenable,
    input                                dm_avalon_s_write,
    input                                dm_avalon_s_read,

    // Avalon slave for DBGREG
    input [31:0]                         dbgreg_avalon_s_writedata,
    output [31:0]                        dbgreg_avalon_s_readdata,
    input [9:0]                          dbgreg_avalon_s_address,
    input [3:0]                          dbgreg_avalon_s_byteenable,
    input                                dbgreg_avalon_s_write,
    input                                dbgreg_avalon_s_read,
    input                                dbgreg_avalon_s_chipselect,
    output                               dbgreg_avalon_s_readdatavalid,
    output                               dbgreg_avalon_s_writeresponsevalid,
    output [1:0]                         dbgreg_avalon_s_response,
    output                               dbgreg_avalon_s_waitrequest_n,

    // System reset
    output                               ndmreset_o,
    input                                ndmreset_ack_i
);

logic dm_debug_req;
logic reg_debug_req, reg_sleep_req;

// signals from/to core
logic         core_instr_req;
logic         core_instr_gnt;
logic         core_instr_rvalid;
logic [31:0]  core_instr_addr;
logic [31:0]  core_instr_rdata;
logic [6:0]   core_instr_rdata_intg;
logic         core_instr_err;

logic         core_data_req;
logic         core_data_gnt;
logic         core_data_rvalid;
logic         core_data_we;
logic [3:0]   core_data_be;
logic [31:0]  core_data_addr;
logic [31:0]  core_data_wdata;
logic [6:0]   core_data_wdata_intg;
logic [31:0]  core_data_rdata;
logic [6:0]   core_data_rdata_intg;
logic         core_data_err;

logic dmi_req_ready;
dm::dmi_req_t dmi_req;
logic dmi_req_valid;
dm::dmi_resp_t dmi_resp;
logic dmi_resp_valid;
logic dmi_resp_ready;
logic dmi_rst_req;

assign bus_instr_read = core_instr_req;
assign bus_instr_addr = core_instr_addr;
assign core_instr_gnt = ~bus_instr_busy & core_instr_req;
assign core_instr_rvalid = bus_instr_rvalid;
assign core_instr_rdata = bus_instr_rdata;
assign core_instr_rdata_intg = '0;
assign core_instr_err = '0;

assign bus_data_read = core_data_req & ~core_data_we;
assign bus_data_addr = core_data_addr;
assign bus_data_write = core_data_req & core_data_we;
assign bus_data_be = core_data_be;
assign bus_data_wdata = core_data_wdata;
assign core_data_gnt = ~bus_data_busy & core_data_req;
assign core_data_rvalid = bus_data_rvalid | bus_data_wrespvalid;
assign core_data_rdata = bus_data_rdata;
assign core_data_rdata_intg = '0;
assign core_data_err = '0;


ibex_top #(
    .PMPEnable        ( 0                                ),
    .PMPGranularity   ( 0                                ),
    .PMPNumRegions    ( 4                                ),
    .MHPMCounterNum   ( 0                                ),
    .MHPMCounterWidth ( 40                               ),
    //.PMPRstCfg[16]
    //.PMPRstAddr[16]
    //.PMPRstMsecCfg
    .RV32E            ( IBEX_RV32E                       ),
    .RV32M            ( ibex_pkg::RV32MSingleCycle       ),
    .RV32B            ( ibex_pkg::RV32BNone              ),
    .RegFile          ( ibex_pkg::RegFileFF              ),
    //.BranchTargetALU
    //.WritebackStage
    .ICache           ( IBEX_ICACHE                      ),
    .ICacheECC        ( 0                                ),
    .ICacheScramble   ( 0                                ),
    //.ICacheScrNumPrinceRoundsHalf
    .BranchPredictor  ( 0                                ),
    .SecureIbex       ( 0                                ),
    .RndCnstLfsrSeed  ( ibex_pkg::RndCnstLfsrSeedDefault ),
    .RndCnstLfsrPerm  ( ibex_pkg::RndCnstLfsrPermDefault ),
    .DbgTriggerEn     ( 0                                ),
    //.DbgHwBreakNum
    .DmBaseAddr       ( 32'h00000000                     ),
    .DmAddrMask       ( 32'h00000FFF                     ),
    .DmHaltAddr       ( 32'h00000800                     ),
    .DmExceptionAddr  ( 32'h00000808                     )
) u_top (
    // Clock and reset
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),
    .test_en_i              (1'b0),
    .scan_rst_ni            (1'b1),
    .ram_cfg_i              ('0),

    // Configuration
    .hart_id_i              ('0),
    .boot_addr_i            (boot_addr_i),

    // Instruction memory interface
    .instr_req_o            (core_instr_req),
    .instr_gnt_i            (core_instr_gnt),
    .instr_rvalid_i         (core_instr_rvalid),
    .instr_addr_o           (core_instr_addr),
    .instr_rdata_i          (core_instr_rdata),
    .instr_rdata_intg_i     (core_instr_rdata_intg),
    .instr_err_i            (core_instr_err),

    // Data memory interface
    .data_req_o             (core_data_req),
    .data_gnt_i             (core_data_gnt),
    .data_rvalid_i          (core_data_rvalid),
    .data_we_o              (core_data_we),
    .data_be_o              (core_data_be),
    .data_addr_o            (core_data_addr),
    .data_wdata_o           (core_data_wdata),
    .data_wdata_intg_o      (core_data_wdata_intg),
    .data_rdata_i           (core_data_rdata),
    .data_rdata_intg_i      (core_data_rdata_intg),
    .data_err_i             (core_data_err),

    // Interrupt inputs
    .irq_software_i         (irq_software_i),
    .irq_timer_i            (irq_timer_i),
    .irq_external_i         (irq_external_i),
    .irq_fast_i             (irq_fast_i),
    .irq_nm_i               (irq_nm_i),

    // Scrambling Interface
    .scramble_key_valid_i   ('0),
    .scramble_key_i         ('0),
    .scramble_nonce_i       ('0),
    .scramble_req_o         (),

    // Debug interface
    .debug_req_i            (dm_debug_req),
    .crash_dump_o           (),
    .double_fault_seen_o    (),

    // Special control signals
    .fetch_enable_i         (reg_sleep_req ? IbexMuBiOff : IbexMuBiOn),
    .alert_minor_o          (),
    .alert_major_internal_o (),
    .alert_major_bus_o      (),
    .core_sleep_o           (core_sleep_o)
);

dm_top #(
    .NrHarts                (1),
    .BusWidth               (32),
    .DmBaseAddress          ('0),
    .SelectableHarts        ('1),
    .ReadByteEnable         (1)
) u_dm_top (
    .clk_i                  (clk_i),
    .rst_ni                 (po_rst_ni),
    .next_dm_addr_i         ('0),
    .testmode_i             (1'b0),
    .ndmreset_o             (ndmreset_o),
    .ndmreset_ack_i         (ndmreset_ack_i),
    .dmactive_o             (),
    .debug_req_o            (dm_debug_req),
    .unavailable_i          (1'b0),
    .hartinfo_i             ('0),

    // Bus device with debug memory (for execution-based debug).
    .slave_req_i            (dm_avalon_s_write | dm_avalon_s_read),
    .slave_we_i             (dm_avalon_s_write),
    .slave_addr_i           ({20'h0, dm_avalon_s_address}),
    .slave_be_i             (dm_avalon_s_byteenable),
    .slave_wdata_i          (dm_avalon_s_writedata),
    .slave_rdata_o          (dm_avalon_s_readdata),

    // Bus host (for system bus accesses, SBA).
    .master_req_o           (),
    .master_add_o           (),
    .master_we_o            (),
    .master_wdata_o         (),
    .master_be_o            (),
    .master_gnt_i           (1'b0),
    .master_r_valid_i       (1'b0),
    .master_r_err_i         (1'b0),
    .master_r_other_err_i   (1'b0),
    .master_r_rdata_i       ('0),

    // TODO
    .dmi_rst_ni             (~dmi_rst_req),
    .dmi_req_valid_i        (dmi_req_valid),
    .dmi_req_ready_o        (dmi_req_ready),
    .dmi_req_i              (dmi_req),
    .dmi_resp_valid_o       (dmi_resp_valid),
    .dmi_resp_ready_i       (dmi_resp_ready),
    .dmi_resp_o             (dmi_resp)
);

avalon_dbg_regif u_avalon_dbg_regif (
    .clk_i(clk_i),
    .rst_i(~rst_ni),
    .avalon_s_writedata(dbgreg_avalon_s_writedata),
    .avalon_s_readdata(dbgreg_avalon_s_readdata),
    .avalon_s_address(dbgreg_avalon_s_address),
    .avalon_s_byteenable(dbgreg_avalon_s_byteenable),
    .avalon_s_write(dbgreg_avalon_s_write),
    .avalon_s_read(dbgreg_avalon_s_read),
    .avalon_s_chipselect(dbgreg_avalon_s_chipselect),
    .avalon_s_readdatavalid(dbgreg_avalon_s_readdatavalid),
    .avalon_s_writeresponsevalid(dbgreg_avalon_s_writeresponsevalid),
    .avalon_s_response(dbgreg_avalon_s_response),
    .avalon_s_waitrequest_n(dbgreg_avalon_s_waitrequest_n),
    .dmi_req_ready_i(dmi_req_ready),
    .dmi_req_o(dmi_req),
    .dmi_req_valid_o(dmi_req_valid),
    .dmi_resp_i(dmi_resp),
    .dmi_resp_valid_i(dmi_resp_valid),
    .dmi_resp_ready_o(dmi_resp_ready),
    .debug_req(reg_debug_req),
    .sleep_req(reg_sleep_req),
    .dmi_rst_req(dmi_rst_req)
);

endmodule