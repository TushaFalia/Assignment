module receiver_tb;

  logic       arst_ni;
  logic       clk_i;
  logic       parity_en_i;
  logic       parity_type_i;
  logic       second_stop_i;
  logic [7:0] data_o;
  logic       valid_o;
  logic       rx_i;

  receiver u_dut (.*);

  initial begin
    $dumpfile("receiver_tb.vcd");
    $dumpvars(0, receiver_tb);


    arst_ni       <= '0;
    clk_i         <= '0;
    parity_en_i   <= '0;
    parity_type_i <= '0;
    second_stop_i <= '0;
    rx_i          <= '1;

    #10ns;
    arst_ni <= '1;
    #10ns;
    arst_ni <= '0; // Reset the DUT 
    #10ns;
    arst_ni <= '1; // Release reset 
  

    fork
      forever #5ns clk_i <= ~clk_i;
    join_none

    

    /* verilog_format: off */
    // DATA A5
                repeat (8) @ (posedge clk_i); // waiting for bhurum bhurum
    rx_i <= '0; repeat (8) @ (posedge clk_i); // start bit

    rx_i <= '1; repeat (8) @ (posedge clk_i); // D0
    rx_i <= '0; repeat (8) @ (posedge clk_i); // D1
    rx_i <= '1; repeat (8) @ (posedge clk_i); // D2
    rx_i <= '0; repeat (8) @ (posedge clk_i); // D3
    rx_i <= '0; repeat (8) @ (posedge clk_i); // D4
    rx_i <= '1; repeat (8) @ (posedge clk_i); // D5
    rx_i <= '0; repeat (8) @ (posedge clk_i); // D6
    rx_i <= '1; repeat (8) @ (posedge clk_i); // D7
    
   #1 rx_i <= '1; repeat (8) @ (posedge clk_i); // stop bit
    /* verilog_format: on */

    #200ns;
    $finish;

  end


endmodule
