module apb_uart_top_tb;

  localparam int ADDR_WIDTH = 5;
  localparam int DATA_WIDTH = 32;
  localparam int SIZE       = 8;

  ////////////////////////////////////////////////////////////
  // Signals
  ////////////////////////////////////////////////////////////

  logic arst_ni;
  logic clk_i;

  // APB interface
  logic                    psel_i;
  logic                    penable_i;
  logic [ADDR_WIDTH-1:0]   paddr_i;
  logic                    pwrite_i;
  logic [DATA_WIDTH-1:0]   pwdata_i;
  logic [DATA_WIDTH/8-1:0] pstrb_i;

  logic                    pready_o;
  logic [DATA_WIDTH-1:0]   prdata_o;
  logic                    pslverr_o;

  // UART
  logic uart_tx_o;
  logic uart_rx_i;

  ////////////////////////////////////////////////////////////
  // DUT
  ////////////////////////////////////////////////////////////

  apb_uart_top #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .SIZE(SIZE)
  ) dut (
      .*
  );

  ////////////////////////////////////////////////////////////
  // Clock generation
  ////////////////////////////////////////////////////////////

  initial begin
    clk_i = 0;
    forever #10 clk_i = ~clk_i;
  end

  ////////////////////////////////////////////////////////////
  // APB Write Task
  ////////////////////////////////////////////////////////////

  task automatic apb_write(
      input logic [ADDR_WIDTH-1:0] addr,
      input logic [DATA_WIDTH-1:0] data
  );
  begin

    // Setup phase
    @(posedge clk_i);
    psel_i    <= 1'b1;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b1;
    paddr_i   <= addr;
    pwdata_i  <= data;
    pstrb_i   <= '1;

    // Access phase
    @(posedge clk_i);
    penable_i <= 1'b1;

    // Wait for slave ready
    while (!pready_o)
      @(posedge clk_i);

    // Complete transfer
    @(posedge clk_i);
    psel_i    <= 0;
    penable_i <= 0;
    pwrite_i  <= 0;

    $display("[%0t] WRITE addr=%h data=%h err=%b",
             $time, addr, data, pslverr_o);

  end
  endtask

  ////////////////////////////////////////////////////////////
  // APB Read Task
  ////////////////////////////////////////////////////////////

  task automatic apb_read(
      input  logic [ADDR_WIDTH-1:0] addr,
      output logic [DATA_WIDTH-1:0] data
  );
  begin

    // Setup phase
    @(posedge clk_i);
    psel_i    <= 1'b1;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b0;
    paddr_i   <= addr;

    // Access phase
    @(posedge clk_i);
    penable_i <= 1'b1;

    while (!pready_o)
      @(posedge clk_i);

    data = prdata_o;

    @(posedge clk_i);
    psel_i    <= 0;
    penable_i <= 0;

    $display("[%0t] READ addr=%h data=%h err=%b",
             $time, addr, data, pslverr_o);

  end
  endtask

  ////////////////////////////////////////////////////////////
  // Test sequence
  ////////////////////////////////////////////////////////////

  logic [31:0] rd_data;

  initial begin

    //------------------------------------------------------
    // Initialize
    //------------------------------------------------------
    arst_ni   = 0;

    psel_i    = 0;
    penable_i = 0;
    pwrite_i  = 0;
    paddr_i   = 0;
    pwdata_i  = 0;
    pstrb_i   = 0;

    uart_rx_i = 1'b1;      // idle UART line

    //------------------------------------------------------
    // Release reset
    //------------------------------------------------------
    repeat(5) @(posedge clk_i);

    arst_ni = 1;

    //------------------------------------------------------
    // Enable UART
    //------------------------------------------------------
    apb_write(5'h00, 32'h00000001);

    //------------------------------------------------------
    // Configure UART
    //------------------------------------------------------
    apb_write(5'h04, 32'h00000010);

    //------------------------------------------------------
    // Read status register
    //------------------------------------------------------
    apb_read(5'h08, rd_data);

    //------------------------------------------------------
    // Send byte 0x55
    //------------------------------------------------------
    apb_write(5'h0C, 32'h00000055);

    //------------------------------------------------------
    // Send byte 0xAA
    //------------------------------------------------------
    apb_write(5'h0C, 32'h000000AA);

    //------------------------------------------------------
    // Read RX register
    //------------------------------------------------------
    apb_read(5'h10, rd_data);

    #1000;

    $finish;

  end

endmodule