module receiver (
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

    // 8-bit data to receive
    output logic [7:0] data_o,
    // Valid signal indicating data_o is ready for reception
    output logic       valid_o,

    // Received serial data input
    input logic rx_i
);

typedef enum logic [3:0] {idle, start_bit, databit_0, databit_1, databit_2, databit_3, databit_4, databit_5, databit_6, databit_7, 
parity_bit, stop_bit_first, stop_bit_second } state_e_t;
    


// Tusha
    logic [7:0] rx_data_shift;  // Shift register for incoming data bits
    logic starting_bit_detected;  // Flag to indicate detection of start bit
    logic parity_checked;
    logic paritydata;
    logic rx_q;
    state_e_t present_bit;  // Current state of the FSM for UART reception
    state_e_t next_bit;  // Next state signal for FSM transitions 


    parameter clktick_per_bit = 8;  // Number of clock cycles per bit (for baud rate timing)
    parameter half_clk_per_bit = clktick_per_bit / 2;  // Half bit time for sampling at the middle of the bit period 
    logic [2:0] bit_clk_counter;  // Counter for clock cycles within a bit period (3 bits to count up to 7 for clktick_per_bit=8)


    assign data_o = rx_data_shift;  // Output the received data
    assign paritydata = ^rx_data_shift;  // Calculate parity from received data bits




    always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      rx_q <= 1'b1; // Reset to idle state (line is high when idle)
    end else begin
      rx_q <= rx_i;
    end
  end



    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            starting_bit_detected <= 1'b0;  // Clear start bit detection on reset
        end 
        else begin
            // Detect falling edge for start bit (rx_i goes from high to low)
           starting_bit_detected <= (rx_i == 1'b0) && (rx_q == 1'b1) && (present_bit == idle); // NEED FSM?
            end
        end
    


    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            present_bit <= idle;  // Reset to idle state on reset
            next_bit <= idle;  // Reset next state to idle on reset
            bit_clk_counter <= '0;  // Reset clock counter on reset
        end else begin
            present_bit <= next_bit;  // Update current state to next state on clock edge
        case (present_bit)
        idle : begin
            
            next_bit <= (starting_bit_detected) ? start_bit : idle;  // Transition to start_bit on start edge 
        
    end

        start_bit : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_0;  // Transition to first data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period 
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within start bit period
                next_bit <= start_bit;  // Stay in start bit state until half bit time is reached
        end
    end

        databit_0 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_1;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_0;  // Stay in data bit state until half bit time is reached
            end
        end 
        databit_1 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_2;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_1;  // Stay in data bit state until half bit time is reached
            end
        end
        databit_2 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_3;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_2;  // Stay in data bit state until half bit time is reached
            end
            
        end
        databit_3 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_4;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_3;  // Stay in data bit state until half bit time is reached
            end
        end
        databit_4 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_5;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_4;  // Stay in data bit state until half bit time is reached
            end
        end
        databit_5 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_6;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_5;  // Stay in data bit state until half bit time is reached
            end
        end
        databit_6 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= databit_7;  // Transition to next data bit state
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_6;  // Stay in data bit state until half bit time is reached
            end
        end
        databit_7 : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit <= (parity_en_i) ? parity_bit : stop_bit_first;  // Conditional transition based on parity enable
                bit_clk_counter <= '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
            else begin
                bit_clk_counter <= bit_clk_counter + 1; // Increment counter within data bit period
                next_bit <= databit_7;  // Stay in data bit state until half bit time is reached
            end
        end
        parity_bit : begin
            next_bit <= stop_bit_first;  // Transition to stop bit state after parity bit
        end
        stop_bit_first : begin
            next_bit <= (second_stop_i) ? stop_bit_second : idle;  // Transition to second stop bit or idle based on enable
        end
        stop_bit_second : begin
            next_bit <= idle;  // Transition back to idle state after second stop bit
        end
        default : begin
            next_bit <= idle;  // Default to idle state for safety
        end
        
    endcase
    end
    end

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            rx_data_shift <= 8'b0;  // Reset shift register on reset
                    // Clear valid signal on reset
        end else begin
           if (starting_bit_detected) begin // start bit detection FSM??
               // Shift in the received bit into the appropriate position 
            case (present_bit) 
                databit_0: rx_data_shift [0] <= rx_q;    
                databit_1: rx_data_shift [1] <= rx_q;
                databit_2: rx_data_shift [2] <= rx_q;
                databit_3: rx_data_shift [3] <= rx_q;
                databit_4: rx_data_shift [4] <= rx_q;
                databit_5: rx_data_shift [5] <= rx_q;
                databit_6: rx_data_shift [6] <= rx_q;
                databit_7: rx_data_shift [7] <= rx_q;
            endcase
            end              
        end
    end 

     always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            parity_checked <= 1'b0;  // Clear parity check on reset
        end else begin
            if (parity_en_i && starting_bit_detected && rx_i) begin
                // Perform parity check based on parity_type_i
                // This is a placeholder for actual parity checking logic
                parity_checked <= parity_type_i ? (rx_i == ~paritydata) : (rx_i == paritydata); // Example parity check
            end else begin
                parity_checked <= 1'b0;  // No parity check if not enabled
            end
        end
    end

endmodule
