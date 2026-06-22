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

typedef enum logic [3:0] {IDLE, START_BIT, DATABIT_0, DATABIT_1, DATABIT_2, DATABIT_3, DATABIT_4, DATABIT_5, DATABIT_6, DATABIT_7, 
PARITY_BIT, STOP_BIT_FIRST, STOP_BIT_SECOND } state_e_t;
    


// Tusha
    logic [7:0] rx_data_shift;  // Shift register for incoming data bits
    logic starting_bit_detected;  // Flag to indicate detection of start bit
    logic parity_checked;
    logic paritydata;
    logic rx_q;
    state_e_t present_bit;  // Current state of the FSM for UART reception
    state_e_t next_bit;  // Next state signal for FSM transitions 
    //logic [7:0] data_pre_o;  // Internal signal for received data before output assignment 


    parameter clktick_per_bit = 8;  // Number of clock cycles per bit (for baud rate timing)
    parameter half_clk_per_bit = clktick_per_bit / 2;  // Half bit time for sampling at the middle of the bit period 
    logic [2:0] bit_clk_counter;  // Counter for clock cycles within a bit period (3 bits to count up to 7 for clktick_per_bit=8)


    //assign data_pre_o = rx_data_shift;  // Output the received data
    assign paritydata = ^rx_data_shift;  // Calculate parity from received data bits






    always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      rx_q <= 1'b1; // Reset to idle state (line is high when idle)
    end else begin
       //if (bit_clk_counter == clktick_per_bit -1) begin  //changed
      rx_q <= rx_i;
    //end
  end
end

  //assign starting_bit_detected = (rx_i == 1'b0) && (rx_q == 1'b1) && (present_bit == IDLE);

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            starting_bit_detected <= 1'b0;  // Clear start bit detection on reset
        end 
        else begin
            // Detect falling edge for start bit (rx_i goes from high to low)
           starting_bit_detected <= (rx_i == 1'b0) && (rx_q == 1'b1) && (present_bit == IDLE); // NEED FSM?
            end
        end 


    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            bit_clk_counter <= '0;
        end else begin
            case (present_bit)
                IDLE : bit_clk_counter <= '0;

                START_BIT : begin
                    // Count half a bit period to align to midpoint of first data bit
                    if (bit_clk_counter == half_clk_per_bit - 1)
                        bit_clk_counter <= '0;
                    else
                        bit_clk_counter <= bit_clk_counter + 1'b1;
                end

                default : begin
                    // Full bit period for all data / parity / stop states
                    if (bit_clk_counter == clktick_per_bit - 1)
                        bit_clk_counter <= '0;
                    else
                        bit_clk_counter <= bit_clk_counter + 1'b1;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            present_bit <= IDLE;
        else
            present_bit <= next_bit;
    end


    always_comb begin
        next_bit = present_bit;  // Default: stay in current state 
            //present_bit = next_bit;  // Update current state to next state on clock edge
        case (present_bit)
        IDLE : begin
            
            next_bit = (starting_bit_detected) ? START_BIT : IDLE;  // Transition to start_bit on start edge 
            

    end

        START_BIT : begin
            if (bit_clk_counter == half_clk_per_bit-1) begin
                next_bit = DATABIT_0;  // Transition to first data bit state
               // bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period 
            end
           
    end

        DATABIT_0 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_1;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end 

        DATABIT_1 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_2;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        DATABIT_2 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_3;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        DATABIT_3 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_4;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        DATABIT_4 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_5;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        DATABIT_5 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_6;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        DATABIT_6 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = DATABIT_7;  // Transition to next data bit state
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end
        
        DATABIT_7 : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
                next_bit = (parity_en_i) ? PARITY_BIT : STOP_BIT_FIRST;  // Conditional transition based on parity enable
                //bit_clk_counter = '0;  // Reset counter at half bit time to sample in the middle of the bit period
            end
        end

        PARITY_BIT : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
            next_bit = STOP_BIT_FIRST;  // Transition to stop bit state after parity bit
        end
    end
        STOP_BIT_FIRST : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
            next_bit = (second_stop_i) ? STOP_BIT_SECOND : IDLE;  // Transition to second stop bit or idle based on enable
        end
    end
        STOP_BIT_SECOND : begin
            if (bit_clk_counter == clktick_per_bit-1) begin
            next_bit = IDLE;  // Transition back to idle state after second stop bit
        end
    end
        default : begin
            next_bit = IDLE;  // Default to idle state for safety
        end
        
    endcase
    end
    

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            rx_data_shift <= 8'b0;  // Reset shift register on reset
                    // Clear valid signal on reset
        end else begin
           if (bit_clk_counter == clktick_per_bit - 1) begin // start bit detection FSM?? change here
               // Shift in the received bit into the appropriate position 
            case (present_bit) 
                DATABIT_0: rx_data_shift [0] <= rx_i;    
                DATABIT_1: rx_data_shift [1] <= rx_i;
                DATABIT_2: rx_data_shift [2] <= rx_i;
                DATABIT_3: rx_data_shift [3] <= rx_i;
                DATABIT_4: rx_data_shift [4] <= rx_i;
                DATABIT_5: rx_data_shift [5] <= rx_i;
                DATABIT_6: rx_data_shift [6] <= rx_i;
                DATABIT_7: rx_data_shift [7] <= rx_i;
                default  : ;  // No action for other states
            endcase
        
            end        
        
        end
    end 

     always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            parity_checked <= 1'b0;  // Clear parity check on reset
             
        end else begin
            if ((present_bit == PARITY_BIT) && (bit_clk_counter == half_clk_per_bit - 1) && parity_en_i) begin
                // Perform parity check based on parity_type_i
                // This is a placeholder for actual parity checking logic
                parity_checked <= parity_type_i ? (rx_i == ~paritydata) : (rx_i == paritydata); // parity check 1 is ok but parity check 0 is error in parity.
            end else begin
                parity_checked <= 1'b0;  // No parity check if not enabled
            end
        end
    end

    always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
        data_o  <= 8'b0;
        valid_o <= 1'b0;
    end
    else begin
        valid_o <= 1'b0;

        if ((present_bit == STOP_BIT_FIRST) &&
            (bit_clk_counter == half_clk_per_bit-1) &&
            rx_i) begin

            data_o  <= rx_data_shift;   // copy whole byte
            valid_o <= 1'b1;            // pulse valid for one clock
        end
    end
end

   
    /*assign valid_o = ((present_bit == STOP_BIT_FIRST) || (present_bit == STOP_BIT_SECOND)) &&   
                        (rx_i==1) && (parity_en_i ? parity_checked: 1'b1) &&
                        (bit_clk_counter == half_clk_per_bit - 1);  // Data is valid at stop bit(s)*/ 

   

endmodule
