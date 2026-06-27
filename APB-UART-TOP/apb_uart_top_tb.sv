module apb_uart_top_tb;

  localparam int ADDR_WIDTH = 5;
  localparam int DATA_WIDTH = 32;

  import uart_pkg::UART_CTRL_OFFSET;
  import uart_pkg::UART_CFG_OFFSET;
  import uart_pkg::UART_STAT_OFFSET;
  import uart_pkg::UART_TX_DATA_OFFSET;
  import uart_pkg::UART_RX_DATA_OFFSET;

  ////////////////////////////////////////////////////////////
  // Signals
  ////////////////////////////////////////////////////////////

  logic                    arst_ni;
  logic                    clk_i;

  // APB interface
  logic                    psel_i;
  logic                    penable_i;
  logic [  ADDR_WIDTH-1:0] paddr_i;
  logic                    pwrite_i;
  logic [  DATA_WIDTH-1:0] pwdata_i;
  logic [DATA_WIDTH/8-1:0] pstrb_i;

  logic                    pready_o;
  logic [  DATA_WIDTH-1:0] prdata_o;
  logic                    pslverr_o;

  // UART
  logic                    uart_tx_o;
  logic                    uart_rx_i;

  ////////////////////////////////////////////////////////////
  // DUT
  ////////////////////////////////////////////////////////////

  apb_uart_top #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

  ////////////////////////////////////////////////////////////
  // Clock generation
  ////////////////////////////////////////////////////////////

  initial begin
    clk_i <= 0;
    forever #10 clk_i <= ~clk_i;
  end

  ////////////////////////////////////////////////////////////
  // APB Write Task
  ////////////////////////////////////////////////////////////

  task automatic apb_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
    begin

      @(posedge clk_i);

      // Setup phase
      psel_i    <= 1'b1;
      penable_i <= 1'b0;
      pwrite_i  <= 1'b1;
      paddr_i   <= addr;
      pwdata_i  <= data;
      pstrb_i   <= '1;
      @(posedge clk_i);

      // Access phase
      // Wait for slave ready
      penable_i <= 1'b1;
      do @(posedge clk_i); while (!pready_o);


      // Complete transfer
      psel_i <= 0;

      $display("[%0t] WRITE addr=%h data=%h err=%b", $time, addr, data, pslverr_o);

    end
  endtask

  ////////////////////////////////////////////////////////////
  // APB Read Task
  ////////////////////////////////////////////////////////////

  task automatic apb_read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);
    begin

      @(posedge clk_i);

      // Setup phase
      psel_i    <= 1'b1;
      penable_i <= 1'b0;
      pwrite_i  <= 1'b0;
      paddr_i   <= addr;
      @(posedge clk_i);

      // Access phase
      // Wait for slave ready
      penable_i <= 1'b1;
      do @(posedge clk_i); while (!pready_o);

      data = prdata_o;
      psel_i <= 0;
      $display("[%0t] READ addr=%h data=%h err=%b", $time, addr, data, pslverr_o);

    end
  endtask

  ////////////////////////////////////////////////////////////
  // Test sequence
  ////////////////////////////////////////////////////////////

  logic [31:0] rd_data;

  initial begin

    $dumpfile("apb_uart_top_tb.vcd");
    $dumpvars(0, apb_uart_top_tb);

    //------------------------------------------------------
    // Initialize
    //------------------------------------------------------
    arst_ni   <= '0;

    psel_i    <= '0;
    penable_i <= '0;
    pwrite_i  <= '0;
    paddr_i   <= '0;
    pwdata_i  <= '0;
    pstrb_i   <= '0;

    uart_rx_i = 1'b1;  // idle UART line

    //------------------------------------------------------
    // Release reset
    //------------------------------------------------------
    repeat (5) @(posedge clk_i);

    arst_ni <= '1;

    //------------------------------------------------------
    // Enable UART
    //------------------------------------------------------
    apb_write(UART_CTRL_OFFSET, 32'h00000001);

    //------------------------------------------------------
    // Configure UART
    //------------------------------------------------------
    apb_write(UART_CFG_OFFSET, 32'h00000010);

    //------------------------------------------------------
    // Read status register
    //------------------------------------------------------
    apb_read(UART_STAT_OFFSET, rd_data);

    //------------------------------------------------------
    // Send byte 0x55
    //------------------------------------------------------
    apb_write(UART_TX_DATA_OFFSET, 32'h00000055);

    //------------------------------------------------------
    // Send byte 0xAA
    //------------------------------------------------------
    apb_write(UART_TX_DATA_OFFSET, 32'h000000AA);

    //------------------------------------------------------
    // Read RX register
    //------------------------------------------------------
    apb_read(UART_RX_DATA_OFFSET, rd_data);

    #5000;

    $finish;

  end

endmodule
