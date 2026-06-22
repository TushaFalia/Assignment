module transmitter (
    // Active low asynchronous reset
    input logic arst_ni,
    // Clock input
    input logic clk_i,

    // Parity enable: 1 to include parity bit, 0 to exclude
    input logic parity_en_i,
    // Parity type: 0 for even parity, 1 for odd parity
    input logic parity_type_i,
    // Second stop bit enable: 1 to include second stop bit, 0 for single stop bit
    input logic second_stop_i,

    // 8-bit data to transmit
    input  logic [7:0] data_i,
    // Valid signal indicating data_i is ready for transmission
    input  logic       valid_i,
    // Ready signal indicating transmitter is ready to accept new data
    output logic       ready_o,

    // Transmitted serial data output
    output logic tx_o
);

  typedef enum logic [2:0] {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP,
    STOP2
  } txrx_states_t;

  txrx_states_t state, next_state;

  logic [7:0]  data_reg;
  logic [2:0]  bit_cnt;
  logic        parity_xor;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // PARITY XOR — only over transmitted bits (constant bounds required by tool)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    parity_xor = ^data_reg[7:0];  // 8 bits
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL BLOCK
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      state    <= IDLE;
      data_reg <= 8'b0;
      bit_cnt  <= 3'b0;
    end else begin
      state <= next_state;

      if (state inside {IDLE, STOP, STOP2} && valid_i)
        data_reg <= data_i;

      if (state == DATA) begin
        if (bit_cnt < (7))
          bit_cnt <= bit_cnt + 1'b1;
        else
          bit_cnt <= 3'b0;
      end else begin
        bit_cnt <= 3'b0;
      end
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // NEXT STATE LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    next_state = state;
    case (state)
      IDLE:    if (valid_i)                            next_state = START;
      START:                                           next_state = DATA;
      DATA:    if (bit_cnt == (7)) begin
                 if (parity_en_i)                      next_state = PARITY;
                 else                                  next_state = STOP;
               end
      PARITY:                                          next_state = STOP;
      STOP:    if (second_stop_i)                      next_state = STOP2;
               else                                    next_state = valid_i ? START : IDLE;
      STOP2:                                           next_state = valid_i ? START : IDLE;
      default:                                         next_state = IDLE;
    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // OUTPUT LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    tx_o         = 1'b1;
    ready_o      = 1'b0;
    case (state)
      IDLE:    ready_o = 1'b1; 
      START:   tx_o         = 1'b0;
      DATA:    tx_o         = data_reg[bit_cnt];
      PARITY:  tx_o         = parity_type_i ? ~parity_xor : parity_xor;
      STOP:    begin tx_o   = 1'b1; ready_o = 1'b1; end
      STOP2:   tx_o         = 1'b1;
    endcase
  end

endmodule