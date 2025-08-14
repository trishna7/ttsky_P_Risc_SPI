`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Individual signal wires for clarity
  reg uart_rx;
  reg spi_miso;
  wire uart_tx;
  wire gpio_pin;
  wire spi_mosi;
  wire spi_clk;
  wire spi_cs_n;

  // Properly initialize all inputs
  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    ena = 1'b1;
    uart_rx = 1'b1;  // UART idle state
    spi_miso = 1'b0; // SPI MISO initially low
    ui_in = 8'b0;
    uio_in = 8'b0;
  end

  // Clock generation
  always #10 clk = ~clk;  // 50MHz clock (20ns period)

  // Input assignments - properly drive ui_in and uio_in
  always @(*) begin
    ui_in[7:4] = 4'b0;
    ui_in[3] = uart_rx;     // UART RX on bit 3 per pinout
    ui_in[2:0] = 3'b0;
    
    uio_in[7:1] = 7'b0;
    uio_in[0] = spi_miso;   // SPI MISO on bit 0
  end

  // Output assignments - extract signals from output buses
  assign uart_tx = uo_out[0];   // UART TX on uo[0]
  assign gpio_pin = uo_out[1];  // GPIO on uo[1]
  
  assign spi_mosi = uio_out[1]; // SPI MOSI on uio[1]
  assign spi_clk = uio_out[2];  // SPI CLK on uio[2]
  assign spi_cs_n = uio_out[3]; // SPI CS_N on uio[3]

  // Instantiate the main module
  tt_um_trish_P_Risc tt_um_trish_P_Risc (
      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // Optional: Add some debug monitoring
  initial begin
    #1000;
    $display("=== Testbench Debug Info ===");
    $display("Clock period: 20ns (50MHz)");
    $display("Reset active low");
    $display("UART RX on ui_in[3]");
    $display("GPIO out on uo_out[1]");
    $display("SPI signals on uio_out[3:1] and uio_in[0]");
  end

endmodule