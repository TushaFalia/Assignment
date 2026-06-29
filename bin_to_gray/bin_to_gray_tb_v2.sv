module bin_to_gray_tb_v2;

  localparam int WIDTH = 4;

  logic [WIDTH-1:0] bin;
  logic [WIDTH-1:0] gray;

  logic dummy_clk;
  logic is_aligned;

  int pass = 0;
  int fail = 0;

  mailbox #(logic [WIDTH-1:0]) dvr_mbx = new(1);
  mailbox #(logic [WIDTH-1:0]) bin_mbx = new();
  mailbox #(logic [WIDTH-1:0]) gray_mbx = new();

  string test_name;
  int    test_len;

  always @(posedge dummy_clk) begin
    is_aligned = 1;
    #1;
    is_aligned = 0;
  end

  bin_to_gray #(
      .N(WIDTH)
  ) dut (
      .bin_i (bin),
      .gray_o(gray)
  );

  task automatic apply_reset(input realtime duration = 100ns);
    #(duration);
    dummy_clk <= '0;
    #(duration);
    dummy_clk <= '1;
    #(duration);
  endtask

  task automatic start_clock(input realtime tp = 10ns);
    fork
      forever begin
        #(tp / 2) dummy_clk <= ~dummy_clk;
      end
    join_none
    @(posedge dummy_clk);
  endtask

  task automatic start_drive();
    fork
      forever begin
        logic [WIDTH-1:0] value;
        dvr_mbx.peek(value);
        wait (is_aligned);
        bin <= value;
        @(posedge dummy_clk);
        dvr_mbx.get(value);
      end
    join_none
  endtask

  task automatic start_monitor();
    fork
      forever begin
        @(posedge dummy_clk);
        bin_mbx.put(bin);
        gray_mbx.put(gray);
      end
    join_none
  endtask

  function automatic logic [WIDTH-1:0] bin_to_gray_func(input logic [WIDTH-1:0] bin_value);
    return (bin_value ^ (bin_value >> 1));
  endfunction

  task automatic start_checker();
    fork
      forever begin
        logic [WIDTH-1:0] bin_value;
        logic [WIDTH-1:0] gray_value;
        logic [WIDTH-1:0] expected_gray;
        bin_mbx.get(bin_value);
        gray_mbx.get(gray_value);
        expected_gray = bin_to_gray_func(bin_value);
        if (gray_value === expected_gray) begin
          pass++;
        end else begin
          fail++;
          $display("Mismatch: bin=%0d, gray=%0d, expected_gray=%0d", bin_value, gray_value,
                   expected_gray);
        end
      end
    join_none
  endtask

  task automatic generate_sequence(int num_samples = 100);
    $display("Generating sequence of %0d samples...", num_samples);
    for (int i = 0; i < num_samples; i++) begin
      dvr_mbx.put(i);
    end
  endtask

  task automatic generate_random_inputs(int num_samples = 100);
    $display("Generating %0d random inputs...", num_samples);
    repeat (num_samples) begin
      dvr_mbx.put($urandom);
    end
  endtask

  function automatic void print_results();
    $display("Test completed: pass=%0d, fail=%0d", pass, fail);
    if (fail == 0) begin
      $display("Test passed!");
    end else begin
      $display("Test failed.");
    end
  endfunction

  initial begin

    if (!$value$plusargs("TEST_NAME=%s", test_name)) begin
      $fatal(1, "TN plusarg is required. Use TN=<test_name> to specify the test.");
    end

    if (!$value$plusargs("TEST_LEN=%d", test_len)) begin
      $fatal(1, "TL plusarg is required. Use TL=<test_length> to specify the test length.");
    end

    $dumpfile("bin_to_gray_tb_v2.vcd");
    $dumpvars(0, bin_to_gray_tb_v2);

    apply_reset();
    start_clock();

    start_drive();
    start_monitor();
    start_checker();

    case (test_name)
      "seq":   generate_sequence(test_len);
      default: generate_random_inputs(test_len);
    endcase
    $display("Mailbox size = %0d", dvr_mbx.num());
    wait(pass + fail == test_len);
    print_results();
    $finish;
  end

endmodule
