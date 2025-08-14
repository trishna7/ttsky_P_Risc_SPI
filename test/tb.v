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

reg uart_rx, spi_miso;
wire uart_tx, gpio_pin, spi_mosi, spi_clk, spi_cs_n ;

always @(*) begin
    
    ui_in[7:4] = 4'b0;
    ui_in[3] = uart_rx;     // UART RX on bit 3 per pinout
    ui_in[2:0] = 3'b0;
    uio_in[0] = spi_miso;

  end

  initial begin
    uart_rx = 1'b1; // UART idle state
end

  assign uart_tx = uo_out[0];   // uo[4]: "uart_tx"
  assign gpio_pin = uo_out[1];  // uo[5]: "gpio_pin"
  assign uio_out[1] = spi_mosi;   // SPI MOSI
  assign uio_out[2] = spi_clk;    // SPI Clock
  assign uio_out[3] = spi_cs_n;
  //assign spi_miso = uio_in[0];

  // Replace tt_um_example with your module name:
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

endmodule
