module transmitter_tb;

  logic arst_ni;
  logic clk_i;
  logic parity_en_i;
  logic parity_type_i;
  logic second_stop_i;
  logic [7:0] data_i;
  logic valid_i;
  logic ready_o;
  logic tx_o;

  transmitter u_dut (.*);

  initial begin
    $dumpfile("transmitter_tb.vcd");
    $dumpvars(0, transmitter_tb);

    arst_ni       <= '0;
    clk_i         <= '0;
    parity_en_i   <= '0;
    parity_type_i <= '0;
    second_stop_i <= '0;
    data_i        <= '0;
    valid_i       <= '0;

    #10ns;
    arst_ni <= '1;

    fork
      forever #5ns clk_i <= ~clk_i;
    join_none

    data_i  <= 8'hA5;  // Load data to be transmitted
    valid_i <= '1;  // Assert valid to start transmission
    do @(posedge clk_i); while (!ready_o);  // Wait until transmitter is ready to accept data
    valid_i <= '0;  // Deassert valid after data is accepted

    #100ns;
    $finish;

  end

endmodule
