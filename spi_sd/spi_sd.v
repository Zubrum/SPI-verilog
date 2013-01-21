module spi_sd
(
    input   wire    clk,
	input	wire	spi_in,
    output  wire    spi_out,
    output  wire    cs,
    output  wire    sck,
	output	wire	led
);


zrb_sd_core #(8) spi_core (
    clk, 
    8'b0, 
    1'b0, 
    spi_in, 
    1'b0, 
    , 
    led, 
    spi_out, 
    cs, 
    sck
    );

endmodule
