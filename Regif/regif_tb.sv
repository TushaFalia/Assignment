`include "package/uart_pkg.sv"

module regif_tb;
  import uart_pkg::*;

  //////////////////////////////////////////////////////////////
  // Signals
  //////////////////////////////////////////////////////////////

  logic        arst_ni;
  logic        clk_i;
  logic [4:0]  addr_i;
  logic [31:0] wdata_i;
  logic        we_i;
  logic        re_i;
  logic [31:0] rdata_o;
  logic        error_o;

  // Config outputs from DUT
  logic        reg_uart_en;
  logic        reg_tx_flush;
  logic        reg_rx_flush;
  logic [11:0] reg_clk_div;
  logic        reg_parity_en;
  logic        reg_parity_type;
  logic        reg_second_stop_bit;

  // Status inputs to DUT (driven by TB, simulating UART hardware)
  logic [9:0]  reg_tx_count;
  logic [9:0]  reg_rx_count;
  logic        reg_tx_data_ready;
  logic [7:0]  reg_tx_data;
  logic        reg_tx_data_valid;
  logic [7:0]  reg_rx_data;
  logic        reg_rx_data_valid;
  logic        reg_rx_data_ready;

  // Pass/fail counter
  int pass_count;
  int fail_count;

  //////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////

  regif dut (
      .arst_ni            (arst_ni),
      .clk_i              (clk_i),
      .addr_i             (addr_i),
      .wdata_i            (wdata_i),
      .we_i               (we_i),
      .re_i               (re_i),
      .rdata_o            (rdata_o),
      .error_o            (error_o),
      .reg_uart_en        (reg_uart_en),
      .reg_tx_flush       (reg_tx_flush),
      .reg_rx_flush       (reg_rx_flush),
      .reg_clk_div        (reg_clk_div),
      .reg_parity_en      (reg_parity_en),
      .reg_parity_type    (reg_parity_type),
      .reg_second_stop_bit(reg_second_stop_bit),
      .reg_tx_count       (reg_tx_count),
      .reg_rx_count       (reg_rx_count),
      .reg_tx_data        (reg_tx_data),
      .reg_tx_data_valid  (reg_tx_data_valid),
      .reg_tx_data_ready  (reg_tx_data_ready),
      .reg_rx_data        (reg_rx_data),
      .reg_rx_data_valid  (reg_rx_data_valid),
      .reg_rx_data_ready  (reg_rx_data_ready)
  );

 logic [31:0] rd_data;

  initial begin 
  clk_i = 0;
  forever #5 clk_i = ~clk_i; 
  end


 task automatic write_reg(
    input logic [4:0] addr,
    input logic [31:0] data
);

begin
    @(posedge clk_i);
    addr_i  <= addr;
    wdata_i <= data;
    we_i    <= 1'b1;
    re_i    <= 1'b0;

    @(posedge clk_i);
    we_i <= 1'b0;

    //#1;

    $display("[%0t] WRITE addr=%h data=%h error=%b",
             $time, addr, data, error_o);

end
endtask

task automatic read_reg(
    input  logic [4:0] addr,
    output logic [31:0] data
);

begin
    @(posedge clk_i);

    addr_i <= addr;
    we_i   <= 1'b0;
    re_i   <= 1'b1;

    //#1; 

    @(posedge clk_i);
    data = rdata_o;

    $display("[%0t] READ addr=%h data=%h error=%b",
             $time, addr, data, error_o);

    re_i <= 1'b0;

end
endtask



initial begin


    $dumpfile("regif_tb.vcd");
    $dumpvars(0, regif_tb);
    //------------------------------------
    // Initialize
    //------------------------------------
    arst_ni = 0;

    addr_i  = 0;
    wdata_i = 0;
    we_i    = 0;
    re_i    = 0;

    reg_tx_count = 10'd5;
    reg_rx_count = 10'd3;

    reg_tx_data_ready = 1;

    reg_rx_data       = 8'hAB;
    reg_rx_data_valid = 1;

    //------------------------------------
    // Release reset
    //------------------------------------
    #25;
    arst_ni = 1;

    //------------------------------------
    // CTRL register
    //------------------------------------
    write_reg(5'h00, 32'h00000007);

    //------------------------------------
    // CFG register
    //------------------------------------
    write_reg(5'h04, 32'h00001234);

    //------------------------------------
    // STATUS register
    //------------------------------------
    read_reg(5'h04, rd_data);

    //------------------------------------
    // RX DATA register
    //------------------------------------
    read_reg(5'h00, rd_data);

    //------------------------------------
    // TX DATA register
    //------------------------------------
    write_reg(5'h0C, 32'h00000055);
    read_reg(5'h0C, rd_data);

    //------------------------------------
    // Error test:
    // TX FIFO not ready
    //------------------------------------
    reg_tx_data_ready = 0;

    write_reg(5'h0C, 32'h000000AA);

    //------------------------------------
    // Error test:
    // RX FIFO empty
    //------------------------------------
    reg_rx_data_valid = 0;

    read_reg(5'h10, rd_data);

    #100;
    $finish;

end

endmodule
