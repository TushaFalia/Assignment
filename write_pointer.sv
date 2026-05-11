module write_pointer #(
     parameter int ADDR_WIDTH = 3
)(
 input logic write_clk,
 input logic write_enable,
 input [ADDR_WIDTH:0] incoming_pointer_read_grey_sync,
 input logic arst_ni,

output logic [ADDR_WIDTH-1:0] write_address,
output logic [ADDR_WIDTH:0] outgoing_pointer_write_grey_sync,
output logic write_full_flag

);

logic [ADDR_WIDTH:0] write_pointer_binary;
logic [ADDR_WIDTH:0] write_pointer_binary_next;
logic [ADDR_WIDTH:0] read_pointer_binary_sync;
logic full_flag_after_compare; 



assign write_address = write_pointer_binary[ADDR_WIDTH-1:0];

// Checking write condition
assign write_pointer_binary_next = write_pointer_binary + (write_enable & ~write_full_flag);

// Writing
always_ff @(posedge write_clk or negedge arst_ni) begin
    if (!arst_ni) begin
        write_pointer_binary <= 4'b0000;
    end else begin
        write_pointer_binary <= write_pointer_binary_next;
    end
end

// Checking/Comparing the FIFO full or not condition
assign full_flag_after_compare = (write_pointer_binary_next [ADDR_WIDTH] != read_pointer_binary_sync [ADDR_WIDTH]) &&
                          (write_pointer_binary_next [ADDR_WIDTH-1:0] == read_pointer_binary_sync [ADDR_WIDTH-1:0]);

//Assigning flag register to flag output

always_ff @(posedge write_clk or negedge arst_ni) begin
    if (!arst_ni) begin
        write_full_flag <= 0;
    end else begin
        write_full_flag <= full_flag_after_compare;
    end
end

//Instantiating modules

bin_to_gray #(
    parameter N = 4
) bin_to_gray_inst (
    .binary_in(write_pointer_binary),
    .gray_out(outgoing_pointer_write_grey_sync)
); 

gray_to_bin #(
    parameter N = 4
) gray_to_bin_inst (
    .gray_in(incoming_pointer_read_grey_sync),
    .binary_out(read_pointer_binary_sync)
); 

endmodule