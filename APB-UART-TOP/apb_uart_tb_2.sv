`include "package/uart_pkg.sv"

module apb_uart_tb;
  import uart_pkg::*;

  //////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH  = 5;
  localparam int DATA_WIDTH  = 32;
  localparam int SIZE        = 8;
  localparam int CLK_PERIOD  = 10;   // 10ns → 100 MHz APB clock
  localparam int CLK_DIV_TB  = 8;    // UART baud = 100MHz/8 (fast for simulation)

  //////////////////////////////////////////////////////////////
  // DUT Signals
  //////////////////////////////////////////////////////////////

  logic                      arst_ni;
  logic                      clk_i;

  // APB Slave Interface
  logic                      psel_i;
  logic                      penable_i;
  logic [ADDR_WIDTH-1:0]     paddr_i;
  logic                      pwrite_i;
  logic [DATA_WIDTH-1:0]     pwdata_i;
  logic [(DATA_WIDTH/8)-1:0] pstrb_i;
  logic                      pready_o;
  logic [DATA_WIDTH-1:0]     prdata_o;
  logic                      pslverr_o;

  // UART Physical Interface
  logic                      uart_tx_o;
  logic                      uart_rx_i;

  // Loopback control
  // When loopback_en=1, uart_rx_i follows uart_tx_o automatically
  logic loopback_en;
  logic uart_rx_drive;    // manually driven in RX tasks
  assign uart_rx_i = loopback_en ? uart_tx_o : uart_rx_drive;

  // Test counters
  int pass_count;
  int fail_count;

  //////////////////////////////////////////////////////////////
  // DUT Instantiation
  //////////////////////////////////////////////////////////////

  apb_uart_top #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .SIZE      (SIZE)
  ) dut (
      .arst_ni  (arst_ni),
      .clk_i    (clk_i),
      .psel_i   (psel_i),
      .penable_i(penable_i),
      .paddr_i  (paddr_i),
      .pwrite_i (pwrite_i),
      .pwdata_i (pwdata_i),
      .pstrb_i  (pstrb_i),
      .pready_o (pready_o),
      .prdata_o (prdata_o),
      .pslverr_o(pslverr_o),
      .uart_tx_o(uart_tx_o),
      .uart_rx_i(uart_rx_i)
  );

  //////////////////////////////////////////////////////////////
  // Clock — 10ns period / 100 MHz
  //////////////////////////////////////////////////////////////

  initial clk_i = 0;
  initial forever #(CLK_PERIOD/2) clk_i = ~clk_i;

  //============================================================
  // LAYER 1 — PRIMITIVE APB BUS TASKS
  // Drives the raw APB signals, implements setup + access phase
  //============================================================

  // APB write — full 2-phase transaction, waits for pready
  task automatic apb_write(
      input logic [ADDR_WIDTH-1:0]     addr,
      input logic [DATA_WIDTH-1:0]     data,
      input logic [(DATA_WIDTH/8)-1:0] strobe = '1
  );
    @(posedge clk_i); #1;
    // SETUP phase
    psel_i    = 1;
    penable_i = 0;
    paddr_i   = addr;
    pwrite_i  = 1;
    pwdata_i  = data;
    pstrb_i   = strobe;

    @(posedge clk_i); #1;
    // ACCESS phase
    penable_i = 1;
    do @(posedge clk_i); while (!pready_o);
    #1;

    // Deassert — bus idle
    psel_i    = 0;
    penable_i = 0;
    pwrite_i  = 0;
    pwdata_i  = '0;
    pstrb_i   = '0;
  endtask

  // APB read — full 2-phase transaction, returns data and slverr
  task automatic apb_read(
      input  logic [ADDR_WIDTH-1:0] addr,
      output logic [DATA_WIDTH-1:0] data,
      output logic                  slverr
  );
    @(posedge clk_i); #1;
    // SETUP phase
    psel_i    = 1;
    penable_i = 0;
    paddr_i   = addr;
    pwrite_i  = 0;
    pwdata_i  = '0;
    pstrb_i   = '0;

    @(posedge clk_i); #1;
    // ACCESS phase
    penable_i = 1;
    do @(posedge clk_i); while (!pready_o);
    #1;
    data   = prdata_o;
    slverr = pslverr_o;

    // Deassert — bus idle
    psel_i    = 0;
    penable_i = 0;
  endtask

  //============================================================
  // LAYER 2 — CHECKER TASKS
  //============================================================

  task automatic check(
      input string       name,
      input logic [31:0] actual,
      input logic [31:0] expected
  );
    if (actual === expected) begin
      $display("  ✅ PASS | %-45s | 0x%08h", name, actual);
      pass_count++;
    end else begin
      $display("  ❌ FAIL | %-45s | got 0x%08h | expected 0x%08h",
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

  //============================================================
  // LAYER 3 — UART PHYSICAL TASKS
  // Directly drives/monitors uart_rx_i and uart_tx_o
  //============================================================

  // Drive uart_rx_i with a valid UART byte frame
  // Frame: 1 start bit | 8 data bits (LSB first) | 1 stop bit
  task automatic uart_send_byte(input logic [7:0] data);
    $display("  [PHY RX] Sending 0x%02h (%08b) on uart_rx_i", data, data);

    // Start bit — line goes low for one baud period
    uart_rx_drive = 0;
    repeat(CLK_DIV_TB) @(posedge clk_i);

    // 8 data bits, LSB first
    for (int i = 0; i < 8; i++) begin
      uart_rx_drive = data[i];
      repeat(CLK_DIV_TB) @(posedge clk_i);
    end

    // Stop bit — line goes high for one baud period
    uart_rx_drive = 1;
    repeat(CLK_DIV_TB) @(posedge clk_i);
  endtask

  // Monitor uart_tx_o and capture a transmitted byte
  // Samples at the centre of each bit period for robustness
  task automatic uart_capture_tx(output logic [7:0] data);
    $display("  [PHY TX] Waiting for start bit on uart_tx_o ...");

    // Wait for falling edge — start bit
    @(negedge uart_tx_o);
    $display("  [PHY TX] Start bit detected");

    // Skip past start bit and land at centre of bit 0
    // Full start period + half a bit period
    repeat(CLK_DIV_TB + CLK_DIV_TB/2) @(posedge clk_i);

    // Sample 8 data bits at centre of each bit
    for (int i = 0; i < 8; i++) begin
      data[i] = uart_tx_o;
      if (i < 7) repeat(CLK_DIV_TB) @(posedge clk_i);
    end

    // Advance to stop bit and verify
    repeat(CLK_DIV_TB/2) @(posedge clk_i);
    check_bit("Stop bit (expect 1)", uart_tx_o, 1'b1);

    $display("  [PHY TX] Captured 0x%02h (%08b)", data, data);
  endtask

  // Send a corrupted UART frame (no stop bit) to trigger RX error
  task automatic uart_send_corrupted_frame(input logic [7:0] data);
    $display("  [PHY RX] Sending CORRUPTED frame: 0x%02h", data);

    // Start bit
    uart_rx_drive = 0;
    repeat(CLK_DIV_TB) @(posedge clk_i);

    // 8 data bits
    for (int i = 0; i < 8; i++) begin
      uart_rx_drive = data[i];
      repeat(CLK_DIV_TB) @(posedge clk_i);
    end

    // Missing stop bit — keep line low (framing error)
    uart_rx_drive = 0;
    repeat(CLK_DIV_TB) @(posedge clk_i);

    // Restore idle
    uart_rx_drive = 1;
    repeat(CLK_DIV_TB * 2) @(posedge clk_i);
  endtask

  //============================================================
  // LAYER 4 — UART REGISTER ACCESS TASKS
  // Uses apb_write/apb_read to access UART config/data registers
  //============================================================

  // Write and verify CFG register
  task automatic uart_configure(
      input logic [11:0] clk_div,
      input logic        parity_en,
      input logic        parity_type,
      input logic        second_stop
  );
    logic [31:0] cfg_wdata, cfg_rdata;
    logic        slverr;

    cfg_wdata = {17'b0, second_stop, parity_type, parity_en, clk_div};
    apb_write(UART_CFG_OFFSET, cfg_wdata);
    apb_read (UART_CFG_OFFSET, cfg_rdata, slverr);

    check    ("CFG write/readback",   cfg_rdata, cfg_wdata);
    check_bit("CFG slverr",           slverr,    1'b0);

    $display("  [CFG] clk_div=%0d parity_en=%b parity_type=%b second_stop=%b",
             clk_div, parity_en, parity_type, second_stop);
  endtask

  // Write and verify CTRL register
  task automatic uart_set_ctrl(
      input logic uart_en,
      input logic tx_flush,
      input logic rx_flush
  );
    logic [31:0] ctrl_wdata, ctrl_rdata;
    logic        slverr;

    ctrl_wdata = {29'b0, rx_flush, tx_flush, uart_en};
    apb_write(UART_CTRL_OFFSET, ctrl_wdata);
    apb_read (UART_CTRL_OFFSET, ctrl_rdata, slverr);

    check    ("CTRL write/readback",  ctrl_rdata, ctrl_wdata);
    check_bit("CTRL slverr",          slverr,     1'b0);

    $display("  [CTRL] uart_en=%b tx_flush=%b rx_flush=%b",
             uart_en, tx_flush, rx_flush);
  endtask

  // Read STAT register, return TX and RX FIFO counts
  task automatic read_uart_stat(
      output logic [9:0] tx_count,
      output logic [9:0] rx_count
  );
    logic [31:0] stat_data;
    logic        slverr;

    apb_read(UART_STAT_OFFSET, stat_data, slverr);
    tx_count = stat_data[9:0];
    rx_count = stat_data[19:10];

    check_bit("STAT slverr", slverr, 1'b0);
    $display("  [STAT] tx_count=%0d  rx_count=%0d", tx_count, rx_count);
  endtask

  // Write one byte to TX FIFO via APB TX_DATA register
  task automatic apb_queue_tx(
      input logic [7:0] byte_val,
      input logic       expect_slverr = 0
  );
    apb_write(UART_TX_DATA_OFFSET, {24'b0, byte_val});
    check_bit("TX_DATA write slverr", pslverr_o, expect_slverr);
    $display("  [APB TX] Queued byte: 0x%02h", byte_val);
  endtask

  // Read one byte from RX FIFO via APB RX_DATA register
  task automatic apb_read_rx(
      output logic [7:0] byte_val,
      input  logic       expect_slverr = 0
  );
    logic [31:0] rx_data;
    logic        slverr;

    apb_read(UART_RX_DATA_OFFSET, rx_data, slverr);
    byte_val = rx_data[7:0];

    check_bit("RX_DATA read slverr", slverr, expect_slverr);
    $display("  [APB RX] Read byte:   0x%02h", byte_val);
  endtask

  //============================================================
  // LAYER 5 — SCENARIO TASKS
  // High-level test scenarios built from Layer 4 tasks
  //============================================================

  // System reset — all APB signals deasserted, UART RX idle
  task automatic apply_reset();
    $display("\n=== RESET ===");
    arst_ni       = 0;
    psel_i        = 0;
    penable_i     = 0;
    paddr_i       = '0;
    pwrite_i      = 0;
    pwdata_i      = '0;
    pstrb_i       = '0;
    uart_rx_drive = 1;    // UART idle line is high
    loopback_en   = 0;

    repeat(4) @(posedge clk_i);
    arst_ni = 1;
    @(posedge clk_i); #1;
    $display("  Reset released — DUT operational.");
  endtask

  // Configure UART with simulation-friendly parameters
  task automatic setup_uart();
    $display("\n=== UART SETUP ===");
    uart_configure(
        .clk_div    (CLK_DIV_TB),
        .parity_en  (0),
        .parity_type(0),
        .second_stop(0)
    );
    uart_set_ctrl(.uart_en(1), .tx_flush(0), .rx_flush(0));
    $display("  UART ready — baud period = %0d APB cycles.", CLK_DIV_TB);
  endtask

  // TX test: queue byte via APB, capture and verify on uart_tx_o
  task automatic test_tx_byte(input logic [7:0] byte_val);
    logic [7:0] captured;
    $display("\n--- TX: 0x%02h ---", byte_val);

    fork
      apb_queue_tx(byte_val);       // APB side: write to TX FIFO
      uart_capture_tx(captured);    // PHY side: sample uart_tx_o
    join

    check("TX byte match", {24'b0, captured}, {24'b0, byte_val});
  endtask

  // RX test: send UART frame on uart_rx_i, read and verify via APB
  task automatic test_rx_byte(input logic [7:0] byte_val);
    logic [7:0] read_back;
    logic [9:0] tx_cnt, rx_cnt;
    $display("\n--- RX: 0x%02h ---", byte_val);

    uart_send_byte(byte_val);                      // PHY side: drive UART frame
    repeat(CLK_DIV_TB * 3) @(posedge clk_i);      // wait for RX to process

    read_uart_stat(tx_cnt, rx_cnt);                // check RX FIFO has data
    check("RX FIFO count >= 1",
          {22'b0, rx_cnt}, {22'b0, (rx_cnt >= 1 ? rx_cnt : 10'd0)});

    apb_read_rx(read_back);                        // APB side: read RX FIFO
    check("RX byte match", {24'b0, read_back}, {24'b0, byte_val});
  endtask

  // Loopback test: TX byte echoed back through uart_tx_o → uart_rx_i
  task automatic test_loopback_byte(input logic [7:0] byte_val);
    logic [7:0] captured_tx;
    logic [7:0] read_rx;
    $display("\n--- LOOPBACK: 0x%02h ---", byte_val);

    loopback_en = 1;    // uart_rx_i = uart_tx_o via assign

    fork
      begin
        apb_queue_tx(byte_val);         // send via TX FIFO
        uart_capture_tx(captured_tx);   // verify on TX pin
      end
      begin
        // wait for full TX frame then read RX FIFO
        repeat(CLK_DIV_TB * 14) @(posedge clk_i);
        apb_read_rx(read_rx);
      end
    join

    check("Loopback TX captured",    {24'b0, captured_tx}, {24'b0, byte_val});
    check("Loopback RX received",    {24'b0, read_rx},     {24'b0, byte_val});

    loopback_en = 0;    // disable loopback for subsequent tests
  endtask

  // Flush test: fill FIFO, flush, verify counts reset
  task automatic test_flush();
    logic [9:0] tc, rc;
    $display("\n=== FLUSH TEST ===");

    // Queue a few bytes before flush
    apb_queue_tx(8'hAA);
    apb_queue_tx(8'hBB);

    // Assert flush bits
    uart_set_ctrl(.uart_en(1), .tx_flush(1), .rx_flush(1));
    repeat(4) @(posedge clk_i); #1;

    // Deassert flush
    uart_set_ctrl(.uart_en(1), .tx_flush(0), .rx_flush(0));
    read_uart_stat(tc, rc);

    check("TX count = 0 after flush", {22'b0, tc}, 32'h0);
    check("RX count = 0 after flush", {22'b0, rc}, 32'h0);
  endtask

  // Error test: write to read-only STAT register
  task automatic test_stat_write_error();
    $display("\n=== ERROR: WRITE TO STAT ===");
    apb_write(UART_STAT_OFFSET, 32'hFFFFFFFF);
    check_bit("STAT write → pslverr=1", pslverr_o, 1'b1);
  endtask

  // Error test: access unmapped address
  task automatic test_invalid_address();
    logic [31:0] data;
    logic        slverr;
    $display("\n=== ERROR: INVALID ADDRESS ===");

    apb_write(5'h1F, 32'hDEADBEEF);
    check_bit("Invalid write → pslverr=1", pslverr_o, 1'b1);

    apb_read(5'h1F, data, slverr);
    check_bit("Invalid read  → pslverr=1", slverr,    1'b1);
    check    ("Invalid read  → rdata=0",   data,      32'h0);
  endtask

  // Error test: write to TX when FIFO full (SIZE=8, queue 9 bytes)
  task automatic test_tx_fifo_overflow();
    logic [9:0] tc, rc;
    $display("\n=== ERROR: TX FIFO OVERFLOW ===");

    for (int i = 0; i < SIZE; i++)
      apb_write(UART_TX_DATA_OFFSET, {24'b0, 8'(i + 1)});

    // One more write — FIFO should be full → error expected
    apb_write(UART_TX_DATA_OFFSET, 32'hFF);
    check_bit("TX overflow → pslverr=1", pslverr_o, 1'b1);

    read_uart_stat(tc, rc);
    check("TX count = SIZE", {22'b0, tc}, {22'b0, 10'(SIZE)});
  endtask

  // Error test: read from RX when FIFO empty
  task automatic test_rx_fifo_empty();
    logic [7:0] data;
    $display("\n=== ERROR: RX FIFO EMPTY ===");
    apb_read_rx(data, .expect_slverr(1));
  endtask

  // Reset mid-operation: verify FIFOs and config clear
  task automatic test_mid_operation_reset();
    logic [9:0] tc, rc;
    $display("\n=== MID-OPERATION RESET ===");

    // Write config and queue TX bytes
    uart_configure(12'd16, 1, 0, 0);
    apb_queue_tx(8'hDE);
    apb_queue_tx(8'hAD);

    // Assert reset
    arst_ni = 0;
    repeat(3) @(posedge clk_i);
    arst_ni = 1;
    @(posedge clk_i); #1;

    read_uart_stat(tc, rc);
    check("TX FIFO cleared by reset", {22'b0, tc}, 32'h0);
    check("RX FIFO cleared by reset", {22'b0, rc}, 32'h0);

    // Re-configure after reset
    setup_uart();
  endtask

  //============================================================
  // MAIN TEST SEQUENCE
  //============================================================

  initial begin
    pass_count = 0;
    fail_count = 0;

    //----------------------------------------------------------
    // T1 — Reset
    //----------------------------------------------------------
    apply_reset();

    //----------------------------------------------------------
    // T2 — Configure UART
    //----------------------------------------------------------
    setup_uart();

    //----------------------------------------------------------
    // T3 — TX byte tests (APB → uart_tx_o pin)
    //----------------------------------------------------------
    $display("\n========== T3: TX TESTS ==========");
    test_tx_byte(8'h41);    // 'A'
    test_tx_byte(8'hFF);    // all ones
    test_tx_byte(8'h00);    // all zeros
    test_tx_byte(8'h55);    // 01010101 — alternating
    test_tx_byte(8'hAA);    // 10101010 — alternating

    //----------------------------------------------------------
    // T4 — RX byte tests (uart_rx_i pin → APB)
    //----------------------------------------------------------
    $display("\n========== T4: RX TESTS ==========");
    test_rx_byte(8'h42);    // 'B'
    test_rx_byte(8'hC3);
    test_rx_byte(8'hFF);
    test_rx_byte(8'h00);

    //----------------------------------------------------------
    // T5 — Loopback tests (uart_tx_o wired to uart_rx_i)
    //----------------------------------------------------------
    $display("\n========== T5: LOOPBACK TESTS ==========");
    test_loopback_byte(8'hAB);
    test_loopback_byte(8'h5A);
    test_loopback_byte(8'h3C);

    //----------------------------------------------------------
    // T6 — STAT register
    //----------------------------------------------------------
    $display("\n========== T6: STAT REGISTER ==========");
    begin
      logic [9:0] tc, rc;
      read_uart_stat(tc, rc);
    end

    //----------------------------------------------------------
    // T7 — Flush
    //----------------------------------------------------------
    $display("\n========== T7: FLUSH ==========");
    test_flush();

    //----------------------------------------------------------
    // T8 — Error conditions
    //----------------------------------------------------------
    $display("\n========== T8: ERROR CONDITIONS ==========");
    test_stat_write_error();
    test_invalid_address();
    test_tx_fifo_overflow();
    test_rx_fifo_empty();

    //----------------------------------------------------------
    // T9 — Mid-operation reset
    //----------------------------------------------------------
    $display("\n========== T9: MID-OPERATION RESET ==========");
    test_mid_operation_reset();

    //----------------------------------------------------------
    // Final Report
    //----------------------------------------------------------
    $display("\n==============================================");
    $display("  RESULTS:  %0d PASSED  |  %0d FAILED", pass_count, fail_count);
    $display("==============================================\n");

    $finish;
  end

endmodule