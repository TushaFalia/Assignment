// =============================================================================
// Module      : receiver
// Description : UART Receiver with FSM, baud counter, midpoint sampling,
//               configurable parity, and configurable stop bits.
// Author      : Tusha
// =============================================================================

module receiver (
    // Active low asynchronous reset
    input  logic       arst_ni,
    // Clock input
    input  logic       clk_i,

    // Parity enable: 1 to include parity bit, 0 to exclude
    input  logic       parity_en_i,
    // Parity type: 0 for even parity, 1 for odd parity
    input  logic       parity_type_i,
    // Second stop bit enable: 1 to include second stop bit, 0 for single stop bit
    input  logic       second_stop_i,

    // 8-bit received data output
    output logic [7:0] data_o,
    // Valid signal: pulses high for one cycle when data_o is ready
    output logic       valid_o,

    // Received serial data input
    input  logic       rx_i
);

// =============================================================================
// Parameters
// =============================================================================

    // Number of clock cycles per UART bit period
    // For RTL verification this is kept small (8) so simulations run fast.
    // In a real APB-UART this would come from a baud divisor register.
    parameter  int CLKS_PER_BIT = 8;
    localparam int HALF_BIT     = CLKS_PER_BIT / 2;          // midpoint = 4
    localparam int CNT_WIDTH    = (CLKS_PER_BIT > 1)
                                  ? $clog2(CLKS_PER_BIT) : 1; // min bits needed

// =============================================================================
// FSM State Encoding
// =============================================================================

    typedef enum logic [3:0] {
        IDLE,
        START_BIT,
        DATABIT_0,
        DATABIT_1,
        DATABIT_2,
        DATABIT_3,
        DATABIT_4,
        DATABIT_5,
        DATABIT_6,
        DATABIT_7,
        PARITY_BIT,
        STOP_BIT_1,
        STOP_BIT_2
    } state_t;

// =============================================================================
// Internal Signals
// =============================================================================

    state_t              present_bit;       // Current FSM state
    state_t              next_bit;          // Next FSM state (combinational)

    logic [CNT_WIDTH-1:0] baud_counter;    // Counts clock cycles within each bit

    logic                rx_q;             // One-cycle delayed rx_i (for edge detect)
    logic                start_detected;   // One-cycle pulse on falling edge of rx_i

    logic [7:0]          rx_data_shift;    // Shift register — stores sampled data bits
    logic                parity_calc;      // XOR of all received data bits
    logic                parity_ok;        // Result of parity check
    logic                parity_err;       // Parity error flag (optional output)

// =============================================================================
// 1. RX Input Register (synchronise external async signal to clk_i)
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            rx_q <= 1'b1;           // idle line is high
        else
            rx_q <= rx_i;
    end

// =============================================================================
// 2. Start Bit Detection (falling edge on rx_i while in IDLE)
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            start_detected <= 1'b0;
        else
            // Falling edge: rx_i went 1→0 AND we are in IDLE
            start_detected <= (rx_i == 1'b0) && (rx_q == 1'b1)
                              && (present_bit == IDLE);
    end

// =============================================================================
// 3. Baud Counter
//    - Frozen (reset) in IDLE
//    - For START_BIT: counts to HALF_BIT-1, then resets
//      (so we enter DATABIT_0 aligned to the midpoint of bit 0)
//    - For all other states: counts to CLKS_PER_BIT-1, then resets
//      (full bit period; sampling happens at HALF_BIT inside each state)
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            baud_counter <= '0;
        end else begin
            case (present_bit)
                IDLE : baud_counter <= '0;

                START_BIT : begin
                    // Count half a bit period to align to midpoint of first data bit
                    if (baud_counter == HALF_BIT - 1)
                        baud_counter <= '0;
                    else
                        baud_counter <= baud_counter + 1'b1;
                end

                default : begin
                    // Full bit period for all data / parity / stop states
                    if (baud_counter == CLKS_PER_BIT - 1)
                        baud_counter <= '0;
                    else
                        baud_counter <= baud_counter + 1'b1;
                end
            endcase
        end
    end

// =============================================================================
// 4. FSM — State Register (sequential)
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            present_bit <= IDLE;
        else
            present_bit <= next_bit;
    end

// =============================================================================
// 5. FSM — Next-State Logic (combinational)
//    Transitions happen when the counter reaches its terminal count.
//    START_BIT uses HALF_BIT-1; all others use CLKS_PER_BIT-1.
// =============================================================================

    always_comb begin
        next_bit = present_bit;     // default: stay in current state

        case (present_bit)

            IDLE : begin
                if (start_detected)
                    next_bit = START_BIT;
            end

            START_BIT : begin
                // After half a bit period we are at the midpoint of bit 0
                if (baud_counter == HALF_BIT - 1)
                    next_bit = DATABIT_0;
            end

            DATABIT_0 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_1;
            DATABIT_1 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_2;
            DATABIT_2 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_3;
            DATABIT_3 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_4;
            DATABIT_4 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_5;
            DATABIT_5 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_6;
            DATABIT_6 : if (baud_counter == CLKS_PER_BIT - 1) next_bit = DATABIT_7;

            DATABIT_7 : begin
                if (baud_counter == CLKS_PER_BIT - 1)
                    next_bit = parity_en_i ? PARITY_BIT : STOP_BIT_1;
            end

            PARITY_BIT : begin
                if (baud_counter == CLKS_PER_BIT - 1)
                    next_bit = STOP_BIT_1;
            end

            STOP_BIT_1 : begin
                if (baud_counter == CLKS_PER_BIT - 1)
                    next_bit = second_stop_i ? STOP_BIT_2 : IDLE;
            end

            STOP_BIT_2 : begin
                if (baud_counter == CLKS_PER_BIT - 1)
                    next_bit = IDLE;
            end

            default : next_bit = IDLE;

        endcase
    end

// =============================================================================
// 6. Data Shift Register — Midpoint Sampling
//    Sample rx_i at baud_counter == HALF_BIT - 1 inside each data bit state.
//    Because we entered DATABIT_0 already aligned to midpoint (from START_BIT),
//    every subsequent state's midpoint is also at HALF_BIT - 1.
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            rx_data_shift <= 8'b0;
        end else if (baud_counter == HALF_BIT - 1) begin
            case (present_bit)
                DATABIT_0 : rx_data_shift[0] <= rx_i;
                DATABIT_1 : rx_data_shift[1] <= rx_i;
                DATABIT_2 : rx_data_shift[2] <= rx_i;
                DATABIT_3 : rx_data_shift[3] <= rx_i;
                DATABIT_4 : rx_data_shift[4] <= rx_i;
                DATABIT_5 : rx_data_shift[5] <= rx_i;
                DATABIT_6 : rx_data_shift[6] <= rx_i;
                DATABIT_7 : rx_data_shift[7] <= rx_i;
                default    : ; // no action for other states
            endcase
        end
    end

// =============================================================================
// 7. Parity Calculation and Check
//    parity_calc = XOR of all 8 received data bits (even parity reference)
//    Check is performed at the midpoint of PARITY_BIT state.
// =============================================================================

    assign parity_calc = ^rx_data_shift;  // even parity of received data

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            parity_ok <= 1'b0;
        end else if (present_bit == PARITY_BIT && baud_counter == HALF_BIT - 1) begin
            // Even parity (parity_type_i=0): received parity bit must equal parity_calc
            // Odd  parity (parity_type_i=1): received parity bit must equal ~parity_calc
            parity_ok <= parity_type_i ? (rx_i == ~parity_calc)
                                       : (rx_i ==  parity_calc);
        end
    end

    // parity_err is exposed for visibility; tie to output if needed
    assign parity_err = parity_en_i && !parity_ok;

// =============================================================================
// 8. Data Output Register
//    Latch rx_data_shift into data_o at the midpoint of STOP_BIT_1.
//    At this point all 8 data bits (and parity if enabled) have been received.
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            data_o <= 8'b0;
        else if (present_bit == STOP_BIT_1 && baud_counter == HALF_BIT - 1)
            data_o <= rx_data_shift;
    end

// =============================================================================
// 9. Valid Output
//    Pulses high for exactly ONE clock cycle when:
//      - We are in STOP_BIT_1 at the midpoint
//      - Stop bit is correctly high (rx_i == 1)
//      - Parity passed (or parity is disabled)
// =============================================================================

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            valid_o <= 1'b0;
        end else begin
            valid_o <= (present_bit == STOP_BIT_1)         &&
                       (baud_counter == HALF_BIT - 1)       &&
                       (rx_i == 1'b1)                       &&  // stop bit must be high
                       (!parity_en_i || parity_ok);             // parity must pass if enabled
        end
    end

endmodule