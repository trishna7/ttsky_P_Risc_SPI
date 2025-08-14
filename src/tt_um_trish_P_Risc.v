`default_nettype none

module tt_um_trish_P_Risc (
     input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
    
  wire reset;
  wire uart_rx, uart_tx;
  wire gpio_pin;
  wire spi_clk, spi_mosi, spi_miso, spi_cs_n;
  
  
  // Reset logic - active low rst_n from TT, active high reset for processor
    assign reset = ~rst_n;
    
    // Input assignments
    assign uart_rx = ui_in[3];      // UART RX on dedicated input
    assign spi_miso = uio_in[0];    // SPI MISO on bidirectional pin
    
    // Output assignments - Dedicated outputs
    assign uo_out[0] = uart_tx;     // UART TX
    assign uo_out[1] = gpio_pin;    // GPIO output
    assign uo_out[7:2] = 6'b000000; // Unused dedicated outputs
    
    // Bidirectional pin assignments
    assign uio_out[0] = 1'b0;       // SPI MISO is input only
    assign uio_out[1] = spi_mosi;   // SPI MOSI
    assign uio_out[2] = spi_clk;    // SPI Clock
    assign uio_out[3] = spi_cs_n;   // SPI Chip Select (active low)
    assign uio_out[7:4] = 4'b0000;  // Unused bidirectional outputs
    
    // Bidirectional pin directions
    assign uio_oe[0] = 1'b0;        // SPI MISO is input
    assign uio_oe[1] = 1'b1;        // SPI MOSI is output
    assign uio_oe[2] = 1'b1;        // SPI Clock is output
    assign uio_oe[3] = 1'b1;        // SPI CS is output
    assign uio_oe[7:4] = 4'b0000;   // Unused pins as inputs
    
    // Instantiate the main processor with SPI
    Processor main_processor (
        .CLK(clk),
        .reset(reset),
        .RX(uart_rx),
        .TX(uart_tx),
        .gpio_out(gpio_pin),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
  

endmodule