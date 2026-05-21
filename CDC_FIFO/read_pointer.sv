module read_pointer #(
     parameter int ADDR_WIDTH = 3
)(
 input logic read_clk,
 input logic read_enable,
 input [ADDR_WIDTH:0] incoming_pointer_write_grey_sync,
 input logic arst_ni, 

output logic [ADDR_WIDTH-1:0] read_address, // check it
output logic [ADDR_WIDTH:0] outgoing_pointer_read_grey_sync,
output logic read_empty_flag

); 

logic [ADDR_WIDTH:0] read_pointer_binary;
logic [ADDR_WIDTH:0] read_pointer_binary_next;
logic [ADDR_WIDTH:0] write_pointer_binary_sync;
logic empty_flag_after_compare; 



assign read_address = read_pointer_binary[ADDR_WIDTH-1:0];

// Checking read condition
assign read_pointer_binary_next = read_pointer_binary + (read_enable & ~read_empty_flag);

// Reading
always_ff @(posedge read_clk or negedge arst_ni) begin
    if (!arst_ni) begin
        read_pointer_binary <= '0;
    end else begin
        read_pointer_binary <= read_pointer_binary_next;
    end
end 

// Checking/Comparing the FIFO empty or not condition
assign empty_flag_after_compare = (read_pointer_binary[ADDR_WIDTH] == write_pointer_binary_sync [ADDR_WIDTH]) &&
                          (read_pointer_binary[ADDR_WIDTH-1:0] != write_pointer_binary_sync [ADDR_WIDTH-1:0]);

//Assigning empty flag register to flag output
always_ff @(posedge read_clk or negedge arst_ni) begin
    if (!arst_ni) begin
        read_empty_flag <= '0;
    end else begin
        read_empty_flag <= empty_flag_after_compare;
    end
end 

//Instantiating modules

bin_to_gray #(
    .N(ADDR_WIDTH + 1)
) bin_to_gray_inst (
    .binary_in(read_pointer_binary),
    .gray_out(outgoing_pointer_read_grey_sync)
);  

gray_to_bin #(
    .N(ADDR_WIDTH + 1)
) gray_to_bin_inst (
    .gray_in(incoming_pointer_write_grey_sync),
    .binary_out(write_pointer_binary_sync)
);  
endmodule

