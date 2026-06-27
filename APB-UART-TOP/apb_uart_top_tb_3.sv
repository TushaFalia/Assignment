module apb_uart_top_tb_3;

  localparam int ADDR_WIDTH = 5;
  localparam int DATA_WIDTH = 32;

  // Must match CFG register value written below
  // CFG = 32'h00000010 → clk_div = 16
  // Baud period = CLK_DIV_TB × CLK_PERIOD = 16 × 20ns = 320ns
  localparam int CLK_DIV_TB  = 16;
  localparam int CLK_PERIOD  = 20;   // 20ns → 50 MHz

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

  logic                    psel_i;
  logic                    penable_i;
  logic [  ADDR_WIDTH-1:0] paddr_i;
  logic                    pwrite_i;
  logic [  DATA_WIDTH-1:0] pwdata_i;
  logic [DATA_WIDTH/8-1:0] pstrb_i;

  logic                    pready_o;
  logic [  DATA_WIDTH-1:0] prdata_o;
  logic                    pslverr_o;

  logic                    uart_tx_o;
  logic                    uart_rx_i;

  // Pass/fail counters
  int pass_count;
  int fail_count;

  ////////////////////////////////////////////////////////////
  // DUT
  ////////////////////////////////////////////////////////////

  apb_uart_top #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

  ////////////////////////////////////////////////////////////
  // Clock — 20ns period / 50 MHz
  ////////////////////////////////////////////////////////////

  initial begin
    clk_i = 0;
    forever #(CLK_PERIOD/2) clk_i = ~clk_i;
  end

  ////////////////////////////////////////////////////////////
  // ── LAYER 1: APB PRIMITIVE TASKS ─────────────────────────
  ////////////////////////////////////////////////////////////

  // APB Write — fixes: deasserts penable_i and pwrite_i after transaction
  task automatic apb_write(
      input logic [ADDR_WIDTH-1:0] addr,
      input logic [DATA_WIDTH-1:0] data
  );
    @(posedge clk_i); #1;

    // SETUP phase
    psel_i    <= 1'b1;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b1;
    paddr_i   <= addr;
    pwdata_i  <= data;
    pstrb_i   <= '1;

    @(posedge clk_i); #1;

    // ACCESS phase — wait for slave ready
    penable_i <= 1'b1;
    do @(posedge clk_i); while (!pready_o);
    #1;

    // Deassert — bus idle              ✅ FIX: was missing in original
    psel_i    <= 1'b0;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b0;
    pwdata_i  <= '0;

    $display("[%0t] WRITE addr=0x%02h data=0x%08h slverr=%b",
             $time, addr, data, pslverr_o);
  endtask

  // APB Read — fixes: deasserts penable_i after transaction
  task automatic apb_read(
      input  logic [ADDR_WIDTH-1:0] addr,
      output logic [DATA_WIDTH-1:0] data
  );
    @(posedge clk_i); #1;

    // SETUP phase
    psel_i    <= 1'b1;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b0;
    paddr_i   <= addr;
    pwdata_i  <= '0;
    pstrb_i   <= '0;

    @(posedge clk_i); #1;

    // ACCESS phase — wait for slave ready
    penable_i <= 1'b1;
    do @(posedge clk_i); while (!pready_o);
    #1;

    data = prdata_o;

    // Deassert — bus idle              ✅ FIX: was missing in original
    psel_i    <= 1'b0;
    penable_i <= 1'b0;

    $display("[%0t] READ  addr=0x%02h data=0x%08h slverr=%b",
             $time, addr, data, pslverr_o);
  endtask

  ////////////////////////////////////////////////////////////
  // ── LAYER 2: CHECKER TASK ────────────────────────────────
  ////////////////////////////////////////////////////////////

  task automatic check(
      input string       name,
      input logic [31:0] actual,
      input logic [31:0] expected
  );
    if (actual === expected) begin
      $display("  ✅ PASS | %-40s | 0x%08h", name, actual);
      pass_count++;
    end else begin
      $display("  ❌ FAIL | %-40s | got 0x%08h | expected 0x%08h",
               name, actual, expected);
      fail_count++;
    end
  endtask

  task automatic check_bit(
      input string name,
      input logic  actual,
      input logic  expected
  );
    check(name, {31'b0, actual}, {31'b0, expected});
  endtask

  ////////////////////////////////////////////////////////////
  // ── LAYER 3: UART PHYSICAL TASKS ─────────────────────────
  // Drives uart_rx_i / monitors uart_tx_o directly
  // Each bit = CLK_DIV_TB APB clock cycles
  ////////////////////////////////////////////////////////////

  // Drive uart_rx_i with a complete UART frame
  // Frame: 1 start bit | 8 data bits (LSB first) | 1 stop bit
  task automatic uart_send_byte(input logic [7:0] data);
    $display("[%0t] [PHY RX] Sending 0x%02h (%08b) on uart_rx_i",
             $time, data, data);

    // Start bit — line low for one baud period
    uart_rx_i = 1'b0;
    repeat(CLK_DIV_TB) @(posedge clk_i);

    // 8 data bits, LSB first
    for (int i = 0; i < 8; i++) begin
      uart_rx_i = data[i];
      repeat(CLK_DIV_TB) @(posedge clk_i);
    end

    // Stop bit — line high for one baud period
    uart_rx_i = 1'b1;
    repeat(CLK_DIV_TB) @(posedge clk_i);

    $display("[%0t] [PHY RX] Frame complete", $time);
  endtask

  // Monitor uart_tx_o and capture a transmitted byte
  // Samples at the centre of each bit period for reliability
  task automatic uart_capture_tx(output logic [7:0] data);
    $display("[%0t] [PHY TX] Waiting for start bit ...", $time);

    // Wait for start bit — TX line falls low
    @(negedge uart_tx_o);
    $display("[%0t] [PHY TX] Start bit detected", $time);

    // Skip past start bit and land at centre of bit 0
    // One full start period + half bit = CLK_DIV_TB + CLK_DIV_TB/2
    repeat(CLK_DIV_TB + CLK_DIV_TB/2) @(posedge clk_i);

    // Sample 8 data bits at centre of each bit
    for (int i = 0; i < 8; i++) begin
      data[i] = uart_tx_o;
      if (i < 7) repeat(CLK_DIV_TB) @(posedge clk_i);
    end

    // Advance to stop bit and verify
    repeat(CLK_DIV_TB) @(posedge clk_i); //change CLK_DIV_TB/2 to CLK_DIV_TB for 2 stop bits
    check_bit("Stop bit (expect 1)", uart_tx_o, 1'b1);

    $display("[%0t] [PHY TX] Captured 0x%02h (%08b)", $time, data, data);
  endtask

  ////////////////////////////////////////////////////////////
  // ── LAYER 4: TX / RX TEST TASKS ──────────────────────────
  ////////////////////////////////////////////////////////////

  // TX test — write byte via APB, verify on uart_tx_o pin
  task automatic test_tx(input logic [7:0] byte_val);
    logic [7:0] captured;
    $display("\n=== TX TEST: send 0x%02h via APB ===", byte_val);

    fork
      // APB side: write byte to TX FIFO
      apb_write(UART_TX_DATA_OFFSET, {24'b0, byte_val});

      // PHY side: capture what comes out on uart_tx_o
      uart_capture_tx(captured);
    join

    check("TX byte match", {24'b0, captured}, {24'b0, byte_val});
  endtask

  // RX test — drive UART frame on uart_rx_i, read back via APB
  task automatic test_rx(input logic [7:0] byte_val);
    logic [31:0] read_data;
    $display("\n=== RX TEST: receive 0x%02h via uart_rx_i ===", byte_val);

    // PHY side: send UART frame
    uart_send_byte(byte_val);

    // Wait for RX FIFO to capture the byte
    repeat(CLK_DIV_TB * 3) @(posedge clk_i);

    // APB side: read from RX FIFO
    apb_read(UART_RX_DATA_OFFSET, read_data);
    check("RX byte match", read_data & 32'hFF, {24'b0, byte_val});
  endtask

  // Loopback test — TX byte returns via uart_tx_o → uart_rx_i → APB RX read
  // This test wires TX output directly to RX input for one byte
  task automatic test_loopback(input logic [7:0] byte_val);
    logic [7:0]  captured_tx;
    logic [31:0] read_rx;
    $display("\n=== LOOPBACK TEST: 0x%02h ===", byte_val);

    fork
      // Branch A: write to TX, capture what leaves uart_tx_o,
      //           then relay that signal onto uart_rx_i
      begin
        apb_write(UART_TX_DATA_OFFSET, {24'b0, byte_val});
        uart_capture_tx(captured_tx);

        // Relay captured frame back as UART input (software loopback)
        uart_send_byte(captured_tx);
      end

      // Branch B: wait for full frame to propagate, then read RX FIFO
      begin
        // TX frame: (start + 8 data + stop) + relay frame = 2 × 10 × CLK_DIV_TB
        repeat(CLK_DIV_TB * 22) @(posedge clk_i);
        apb_read(UART_RX_DATA_OFFSET, read_rx);
      end
    join

    check("Loopback TX captured",  {24'b0, captured_tx}, {24'b0, byte_val});
    check("Loopback RX received",  read_rx & 32'hFF,     {24'b0, byte_val});
  endtask

  ////////////////////////////////////////////////////////////
  // ── TEST SEQUENCE ─────────────────────────────────────────
  ////////////////////////////////////////////////////////////

  logic [31:0] rd_data;

  initial begin
    $dumpfile("apb_uart_top_tb_3.vcd");
    $dumpvars(0, apb_uart_top_tb_3);

    pass_count = 0;
    fail_count = 0;

    //----------------------------------------------------------
    // Initialize
    //----------------------------------------------------------
    arst_ni   <= 1'b0;
    psel_i    <= 1'b0;
    penable_i <= 1'b0;
    pwrite_i  <= 1'b0;
    paddr_i   <= '0;
    pwdata_i  <= '0;
    pstrb_i   <= '0;
    uart_rx_i  = 1'b1;    // UART idle line is high

    //----------------------------------------------------------
    // Release reset
    //----------------------------------------------------------
    repeat(5) @(posedge clk_i);
    arst_ni <= 1'b1;
    @(posedge clk_i); #1;
    $display("\n[%0t] Reset released.", $time);

    //----------------------------------------------------------
    // T1 — Enable UART
    // CTRL[2:0] = {rx_flush, tx_flush, uart_en} = 3'b001
    //----------------------------------------------------------
    $display("\n=== T1: ENABLE UART ===");
    apb_write(UART_CTRL_OFFSET, 32'h00000001);
    apb_read (UART_CTRL_OFFSET, rd_data);
    check("CTRL readback (uart_en=1)", rd_data, 32'h00000001);

    //----------------------------------------------------------
    // T2 — Configure UART
    // CFG[14:0] = {second_stop, parity_type, parity_en, clk_div[11:0]}
    // 32'h00000010 → clk_div=16, no parity, 1 stop bit
    // Baud period = 16 × 20ns = 320ns
    //----------------------------------------------------------
    $display("\n=== T2: CONFIGURE UART ===");
    apb_write(UART_CFG_OFFSET, 32'h00000010);
    apb_read (UART_CFG_OFFSET, rd_data);
    check("CFG readback (clk_div=16)", rd_data, 32'h00000010);

    //----------------------------------------------------------
    // T3 — Read status register (TX/RX FIFO counts = 0)
    //----------------------------------------------------------
    $display("\n=== T3: STATUS REGISTER ===");
    apb_read(UART_STAT_OFFSET, rd_data);
    $display("  STAT = 0x%08h (tx_count=%0d rx_count=%0d)",
              rd_data, rd_data[9:0], rd_data[19:10]);

    //----------------------------------------------------------
    // T4 — TX tests: write via APB, verify on uart_tx_o
    //----------------------------------------------------------
    $display("\n========== T4: TX TESTS ==========");
    test_tx(8'h55);    // 01010101
    test_tx(8'hAA);    // 10101010
    test_tx(8'hFF);    // 11111111
    test_tx(8'h00);    // 00000000
    test_tx(8'hA5);    // 10100101

    //----------------------------------------------------------
    // T5 — RX tests: drive uart_rx_i, read via APB
    //----------------------------------------------------------
    $display("\n========== T5: RX TESTS ==========");
    test_rx(8'h42);    // 'B'
    test_rx(8'hC3);
    test_rx(8'hFF);
    test_rx(8'h00);
    test_rx(8'h5A);

    //----------------------------------------------------------
    // T6 — Loopback: TX output replayed as RX input
    //----------------------------------------------------------
    $display("\n========== T6: LOOPBACK TESTS ==========");
    test_loopback(8'hAB);
    test_loopback(8'h3C);

    //----------------------------------------------------------
    // T7 — Status register after transfers
    //----------------------------------------------------------
    $display("\n=== T7: STATUS AFTER TRANSFERS ===");
    apb_read(UART_STAT_OFFSET, rd_data);
    $display("  STAT = 0x%08h (tx_count=%0d rx_count=%0d)",
              rd_data, rd_data[9:0], rd_data[19:10]);

    //----------------------------------------------------------
    // T8 — Flush FIFOs and verify
    //----------------------------------------------------------
    $display("\n=== T8: FLUSH ===");
    // CTRL = {rx_flush=1, tx_flush=1, uart_en=1} = 3'b111
    apb_write(UART_CTRL_OFFSET, 32'h00000007);
    repeat(4) @(posedge clk_i); #1;
    // Clear flush bits
    apb_write(UART_CTRL_OFFSET, 32'h00000001);
    apb_read (UART_STAT_OFFSET, rd_data);
    check("TX count = 0 after flush", {22'b0, rd_data[9:0]},  32'h0);
    check("RX count = 0 after flush", {22'b0, rd_data[19:10]}, 32'h0);

    //----------------------------------------------------------
    // T9 — Error: write to RO STAT register
    //----------------------------------------------------------
    $display("\n=== T9: ERROR CONDITION ===");
    apb_write(UART_STAT_OFFSET, 32'hFFFFFFFF);
    check_bit("STAT write → pslverr=1", pslverr_o, 1'b1);

    //----------------------------------------------------------
    // Final report
    //----------------------------------------------------------
    #(CLK_PERIOD * 10);
    $display("\n==============================================");
    $display("  RESULTS:  %0d PASSED  |  %0d FAILED", pass_count, fail_count);
    $display("==============================================\n");

    $finish;
  end

endmodule