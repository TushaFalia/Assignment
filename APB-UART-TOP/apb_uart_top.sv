module apb_uart_top #(
    parameter int ADDR_WIDTH = 5,
    parameter int DATA_WIDTH = 32,
    parameter int SIZE = 8
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


///////**********************////////////////////////


//apbmemif to regif connections////////////////////////////
logic [ADDR_WIDTH-1:0] apbmemif_maddr_o_to_regif_addr_i; // address data array were unmatched in width.
logic [DATA_WIDTH-1:0] apbmemif_mwdata_o_to_regif_wdata_i;
logic [DATA_WIDTH-1:0] apbmemif_mrdata_i_to_regif_rdata_o;
logic [(DATA_WIDTH/8)-1:0] apbmemif_mstrb_o_to_apbmemif_pstrb_i;

logic apbmemif_to_regif_we_i_and_re_i;

//////////////////********************//////////////////

//regif to TX CDC FIFO connections//////////////////////////////////////
logic [7:0] regif_reg_tx_data_to_tx_cdc_fifo_datain_i;
logic regif_reg_tx_data_valid_to_tx_cdc_fifo_datain_valid_i;
logic regif_reg_tx_data_ready_to_tx_cdc_fifo_datain_ready_i;
logic [SIZE:0] regif_reg_tx_data_count_to_tx_cdc_fifo_datain_count_i;

///////////**************/////////////////////////

//regif to RX CDC FIFO connections//////////////////////////////////////
logic [7:0] rx_cdc_fifo_data_out_o_to_regif_reg_rx_data;
logic rx_cdc_fifo_data_out_valid_o_to_regif_reg_rx_data_valid;
logic rx_cdc_fifo_data_out_ready_i_to_regif_reg_rx_data_ready;
logic [SIZE:0] rx_cdc_fifo_data_out_count_o_to_regif_reg_rx_count;

//////////////****************//////////////////////////////

//regif to TX & RX module connections//////////////////////////////////////
logic parity_enable;
logic parity_type;
logic second_stop_bit;


/////////////////********************///////////////////////////

//////CDC FIFO TX to Transmitter connections//////////////////////////////////////
logic [7:0] tx_cdc_fifo_data_out_o_to_transmitter_data_i;
logic tx_cdc_fifo_data_out_valid_o_to_transmitter_valid_i;
logic tx_cdc_fifo_data_out_ready_i_to_transmitter_ready_i;


///////////********************////////////////////////////////


///////////CDC FIFO RX to Receiver connections//////////////////////////////////////
logic [7:0] rx_cdc_fifo_data_in_i_to_receiver_data_o;
logic rx_cdc_fifo_data_in_valid_i_to_receiver_valid_o;


///////*********************///////////////////////////

//////clock divder connections//////////////////////////////////////
/////RX////////////
logic [11:0] regif_reg_clk_div_to_rx_clk_div_i;
logic rx_clk_div_en_o_to_receiver_clk_i; 

////////*************//////////////////////////////

//////TX////////////
logic tx_clk_div_en_o_to_transmitter_clk_i; 

/////////********************/////////////////////////

assign apbmemif_to_regif_we_i_and_re_i = mreq_o & mwe_o; // mreq_o and mwe_o are not declared here




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
    .mreq_o(apbmemif_mreq_o_to_apbmemif_mack_i),  // regif port required?? 
    .maddr_o(maddr_o_to_regif_addr_i),
    .mwe_o(apbmemif_to_regif_we_i_and_re_i),
    .mwdata_o(apbmemif_mwdata_o_to_regif_wdata_i),
    .mstrb_o(apbmemif_mstrb_o_to_apbmemif_pstrb_i), // regif port required??  
    .mack_i(apbmemif_mack_i_to_apbmemif_mreq_o), // regif port required??  
    .mrdata_i(apbmemif_mrdata_i_to_regif_rdata_o),
    .mresp_i() //  // regif port required?? 
);

/////////////////********************///////////////////////////////

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
    .reg_uart_en(),
    .reg_tx_flush(),  // port missing in CDC FIFO?
    .reg_rx_flush(), // port missing in CDC FIFO? 

    .reg_clk_div(regif_reg_clk_div_to_rx_clk_div_i),
    .reg_parity_en(parity_enable),
    .reg_parity_type(parity_type),
    .reg_second_stop_bit(second_stop_bit),

    // Status inputs from UART core
    .reg_tx_count(regif_reg_tx_data_count_to_tx_cdc_fifo_datain_count_i),
    .reg_rx_count(rx_cdc_fifo_data_out_count_o_to_regif_reg_rx_count),

    // Data interface to UART core
    .reg_tx_data(regif_reg_tx_data_to_tx_cdc_fifo_datain_i),
    .reg_tx_data_valid(regif_reg_tx_data_valid_to_tx_cdc_fifo_datain_valid_i),
    .reg_tx_data_ready(regif_reg_tx_data_ready_to_tx_cdc_fifo_datain_ready_i),

    .reg_rx_data(rx_cdc_fifo_data_out_o_to_regif_reg_rx_data),
    .reg_rx_data_valid(rx_cdc_fifo_data_out_valid_o_to_regif_reg_rx_data_valid),
    .reg_rx_data_ready(rx_cdc_fifo_data_out_ready_i_to_regif_reg_rx_data_ready)
);

//////////////////**************************///////////////////////

/// CDC FIFO for the TX 

cdc_fifo #(
    .DATA_WIDTH(8),
    .SIZE(4) // Example size, can be adjusted as needed
) u_cdc_fifo_tx (
    // Data input side (APB clock domain)
    .data_in_arst_ni(arst_ni),
    .data_in_clk_i(clk_i),
    .data_in_i(regif_reg_tx_data_to_tx_cdc_fifo_datain_i),
    .data_in_valid_i(regif_reg_tx_data_valid_to_tx_cdc_fifo_datain_valid_i),
    .data_in_ready_o(regif_reg_tx_data_ready_to_tx_cdc_fifo_datain_ready_i),
    .data_in_count_o(regif_reg_tx_data_count_to_tx_cdc_fifo_datain_count_i),

    // Data output side (UART clock domain, assuming same as APB for simplicity)
    .data_out_arst_ni(),
    .data_out_clk_i(tx_clk_div_en_o_to_transmitter_clk_i),
    .data_out_o(tx_cdc_fifo_data_out_o_to_transmitter_data_i), // Connect to UART transmitter data input
    .data_out_valid_o(tx_cdc_fifo_data_out_valid_o_to_transmitter_valid_i), // Connect to UART transmitter valid signal
    .data_out_ready_i(tx_cdc_fifo_data_out_ready_i_to_transmitter_ready_i), // Connect to UART transmitter ready signal
    .data_out_count_o()
);

/////////////////*************************//////////////////////

/// CDC FIFO for the RX 

cdc_fifo #(
    .DATA_WIDTH(8),
    .SIZE(4) // Example size, can be adjusted as needed
) u_cdc_fifo_rx (
    // Data input side (UART clock domain)
    .data_in_arst_ni(),
    .data_in_clk_i(rx_clk_div_en_o_to_receiver_clk_i),
    .data_in_i(rx_cdc_fifo_data_in_i_to_receiver_data_o),
    .data_in_valid_i(rx_cdc_fifo_data_in_valid_i_to_receiver_valid_o),
    .data_in_ready_o(),
    .data_in_count_o(),

    // Data output side (APB clock domain, assuming same as APB for simplicity)
    .data_out_arst_ni(arst_ni),
    .data_out_clk_i(clk_i),
    .data_out_o(rx_cdc_fifo_data_out_o_to_regif_reg_rx_data), // Connect to UART receiver data output
    .data_out_valid_o(rx_cdc_fifo_data_out_valid_o_to_regif_reg_rx_data_valid), // Connect to UART transmitter valid signal
    .data_out_ready_i(rx_cdc_fifo_data_out_ready_i_to_regif_reg_rx_data_ready), // Connect to UART transmitter ready signal
    .data_out_count_o(rx_cdc_fifo_data_out_count_o_to_regif_reg_rx_count)
);

//////////////////////*********///////////////////////////

/////// TX module instantiation//////////////////////////////////

transmitter u_transmitter (
    // Active low asynchronous reset
    .arst_ni(arst_ni),
    // Clock input
    .clk_i(tx_clk_div_en_o_to_transmitter_clk_i),

    // Parity enable: 1 to include parity bit, 0 to exclude
    .parity_en_i(parity_enable),
    // Parity type: 0 for even parity, 1 for odd parity
    .parity_type_i(parity_type),
    // Second stop bit enable: 1 to include second stop bit, 0 for single stop bit
    .second_stop_i(second_stop_bit),

    // 8-bit data to transmit
    .data_i(tx_cdc_fifo_data_out_o_to_transmitter_data_i),
    // Valid signal indicating data_i is ready for transmission
    .valid_i(tx_cdc_fifo_data_out_valid_o_to_transmitter_valid_i),
    // Ready signal indicating transmitter is ready to accept new data
    .ready_o(),

    // Transmitted serial data output
    .tx_o(uart_tx_o)
);

//////////////////******************//////////////////////////////


////////////RX module instantiation//////////////////////////////////

receiver u_receiver (
    // Active low asynchronous reset
    .arst_ni(arst_ni),
    // Clock input
    .clk_i(rx_clk_div_en_o_to_receiver_clk_i),

    // Parity enable: 1 to include parity bit, 0 to exclude
    .parity_en_i(parity_enable),
    // Parity type: 0 for even parity, 1 for odd parity
    .parity_type_i(parity_type),
    // Second stop bit enable: 1 to include second stop bit, 0 for single stop bit
    .second_stop_i(second_stop_bit),

    // 8-bit data to receive
    .data_o(rx_cdc_fifo_data_in_i_to_receiver_data_o),
    // Valid signal indicating data_o is ready for reception
    .valid_o(rx_cdc_fifo_data_in_valid_i_to_receiver_valid_o),

    // Received serial data input
    .rx_i(uart_rx_i)
);

///////////////////*****************////////////////////


//////Clock frequency divider instantiation//////////////////////////////////
////RX ///////

clk_freq_div #(
.DIV_WIDTH(32)
) u_rx_clk_div (
    .arst_ni(arst_ni),
    .clk_i(clk_i),
    .div_i(regif_reg_clk_div_to_rx_clk_div_i),
    .en_o(rx_clk_div_en_o_to_receiver_clk_i)
);

///////////////********************/////////////////////////

/////TX ///////

clk_freq_div #(
.DIV_WIDTH (4)
) u_tx_clk_div_8 (
    .arst_ni(arst_ni),
    .clk_i(rx_clk_div_en_o_to_receiver_clk_i),
    .div_i(4'd8),
    .en_o(tx_clk_div_en_o_to_transmitter_clk_i)
);

///////////********************/////////////////////////

endmodule