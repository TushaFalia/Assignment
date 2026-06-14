`include "package/uart_pkg.sv"

module regif (
    input logic arst_ni,
    input logic clk_i,

    input  logic [ 2:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    input  logic        re_i,
    output logic [31:0] rdata_o,
    output logic        error_o,

    output logic reg_uart_en,
    output logic reg_tx_flush,
    output logic reg_rx_flush,

    output logic [11:0] reg_clk_div,
    output logic        reg_parity_en,
    output logic        reg_parity_type,
    output logic        reg_second_stop_bit,

    input logic [9:0] reg_tx_count,
    input logic [9:0] reg_rx_count,

    output logic [7:0] reg_tx_data,
    output logic       reg_tx_data_valid,
    input  logic       reg_tx_data_ready,

    input  logic [7:0] reg_rx_data,
    input  logic       reg_rx_data_valid,
    output logic       reg_rx_data_ready
);

  import uart_pkg::UART_CTRL_OFFSET;
  import uart_pkg::UART_CFG_OFFSET;
  import uart_pkg::UART_STAT_OFFSET;
  import uart_pkg::UART_TX_DATA_OFFSET;
  import uart_pkg::UART_RX_DATA_OFFSET;

  logic wr_error;
  logic rd_error;

  always_comb begin
    case ({
      we_i, re_i
    })
      'b00: error_o = '0;
      'b10: error_o = wr_error;
      'b01: error_o = rd_error;
      default: error_o = '1;
    endcase
  end

  always_comb begin
    rd_error          = 1'b1;
    reg_rx_data_ready = '0;

    case (addr_i)

      UART_CTRL_OFFSET: begin
        rdata_o  = {'0, reg_rx_flush, reg_tx_flush, reg_uart_en};
        rd_error = 1'b0;
      end

      UART_CFG_OFFSET: begin
        rdata_o  = {'0, reg_second_stop_bit, reg_parity_type, reg_parity_en, reg_clk_div};
        rd_error = 1'b0;
      end

      UART_STAT_OFFSET: begin
        rdata_o  = {'0, reg_rx_count, reg_tx_count};
        rd_error = 1'b0;
      end

      UART_RX_DATA_OFFSET: begin
        reg_rx_data_ready = re_i;
        rdata_o = {'0, reg_rx_data};
        rd_error = ~reg_rx_data_valid & re_i;
      end

    endcase
  end

  always_comb begin
    reg_tx_data       = wdata_i[7:0];
    reg_tx_data_valid = '0;
    wr_error          = 1'b1;

    case (addr_i)

      UART_CTRL_OFFSET: begin
        wr_error = 1'b0;
      end

      UART_CFG_OFFSET: begin
        wr_error = 1'b0;
      end

      UART_STAT_OFFSET: begin
        wr_error = 1'b0;
      end

      UART_TX_DATA_OFFSET: begin
        reg_tx_data_valid = we_i;
        wr_error = ~reg_tx_data_ready & we_i;
      end

    endcase
  end


  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (arst_ni == 1'b0) begin
      reg_uart_en         <= '0;
      reg_tx_flush        <= '0;
      reg_rx_flush        <= '0;
      reg_clk_div         <= '0;
      reg_parity_en       <= '0;
      reg_parity_type     <= '0;
      reg_second_stop_bit <= '0;
    end else if (~wr_error & we_i) begin
      case (addr_i)

        UART_CTRL_OFFSET: begin
          {reg_rx_flush, reg_tx_flush, reg_uart_en} = wdata_i[2:0];
        end

        UART_CFG_OFFSET: begin
          {reg_second_stop_bit, reg_parity_type, reg_parity_en, reg_clk_div} = wdata_i[14:0];
        end

        UART_STAT_OFFSET: begin
          {reg_rx_count, reg_tx_count} = wdata_i[19:0];
        end

      endcase
    end
  end

endmodule
