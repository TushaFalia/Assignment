module apb_uart_top #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
) (
    input logic arst_ni,
    input logic clk_i,

    // APB Slave Interface Inputs
    input logic                        psel_i,
    input logic                        penable_i,
    input logic [      ADDR_WIDTH-1:0] paddr_i,
    input logic                        pwrite_i,
    input logic [      DATA_WIDTH-1:0] pwdata_i,
    input logic [(DATA_WIDTH / 8)-1:0] pstrb_i,

    // APB Slave Interface Outputs
    output logic                  pready_o,
    output logic [DATA_WIDTH-1:0] prdata_o,
    output logic                  pslverr_o,

    // UART Interface Outputs
    output logic uart_tx_o,

    // UART Interface Inputs
    input logic uart_rx_i
);

logic to_regif_we_i;
logic to_regif_re_i;


//apbmemif connections///////////////////////////////////
logic apbmemif_mack_i_to_apbmemif_mreq_o;
////////////////////////////////////////////////


//apbmemif to regif connections////////////////////////////
logic maddr_o_to_regif_addr_i;
logic [DATA_WIDTH-1:0] apbmemif_mwdata_o_to_regif_wdata_i;
logic [DATA_WIDTH-1:0] apbmemif_mrdata_i_to_regif_rdata_o;
logic [(DATA_WIDTH/8)-1:0] apbmemif_mstrb_o_to_apbmemif_pstrb_i;

logic apbmemif_to_regif_we_i_and_re_i;



/////////////////////////////////////////////////////////////////

apbmemif_to_regif_we_i_and_re_i = mreq_o & mwe_o;
//to_regif_re_i = mreq_o & ~mwe_o 


// .mwe_o (we_i)





////Instantiations//////////////////////////////////////////

// APB Memory Interface//////////////////////

apb_memif #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_apb_memif (
    .arst_ni(arst_ni),
    .clk_i(clk_i),

    // APB Slave Interface
    .psel_i(psel_i),
    .penable_i(penable_i),
    .paddr_i(paddr_i),
    .pwrite_i(pwrite_i),
    .pwdata_i(pwdata_i),
    .pstrb_i(pstrb_i),
    .pready_o(pready_o),
    .prdata_o(prdata_o),
    .pslverr_o(pslverr_o),

    // Memory Interface
    .mreq_o(apbmemif_mreq_o_to_apbmemif_mack_i),
    .maddr_o(maddr_o_to_regif_addr_i),
    .mwe_o(apbmemif_to_regif_we_i_and_re_i),
    .mwdata_o(apbmemif_mwdata_o_to_regif_wdata_i),
    .mstrb_o(apbmemif_mstrb_o_to_apbmemif_pstrb_i),
    .mack_i(apbmemif_mack_i_to_apbmemif_mreq_o),
    .mrdata_i(apbmemif_mrdata_i_to_regif_rdata_o),
    .mresp_i('0) // Assuming no error response from memory for simplicity
);

// Register Interface/////////////////////////

regif u_regif (
    .arst_ni(arst_ni),
    .clk_i(clk_i),

    .addr_i(maddr_o_to_regif_addr_i),
    .wdata_i(apbmemif_mwdata_o_to_regif_wdata_i),
    .we_i(apbmemif_to_regif_we_i_and_re_i),
    .re_i(~apbmemif_to_regif_we_i_and_re_i),
    .rdata_o(apbmemif_mrdata_i_to_regif_rdata_o),
    .error_o(), // Ignoring error output for simplicity

    // Control signals to UART core
    .reg_uart_en(et),
    .reg_tx_flush(),
    .reg_rx_flush(),

    .reg_clk_div(),
    .reg_parity_en(),
    .reg_parity_type(),
    .reg_second_stop_bit(),

    // Status inputs from UART core
    .reg_tx_count(),
    .reg_rx_count(),

    // Data interface to UART core
    .reg_tx_data(),
    .reg_tx_data_valid(),
    .reg_tx_data_ready(),

    .reg_rx_data(),
    .reg_rx_data_valid(),
    .reg_rx_data_ready()
);


































endmodule