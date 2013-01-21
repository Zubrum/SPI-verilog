module zrb_clk_generator
/*
zrb_clk_generator #(50000000,10000000) instance_name(input_clk, reset, low_full_speed, output_clk);
*/
    #(parameter INPUT_CLK = 50000000, parameter OUTPUT_CLK = 5000000)
    (
    input   wire                clk,
    input   wire                reset,
    input   wire                low_full_speed,
    output  wire                output_clk
    );
wire    [ 28 :  0 ] LOW_CLK = 29'd200000;
wire    [ 28 :  0 ] clk_tic = ~low_full_speed ? 2*LOW_CLK : 2*OUTPUT_CLK;
reg     [ 28 :  0 ] r_tx = 29'b0;
wire    [ 28 :  0 ] inc_tx = r_tx[28] ? (clk_tic) : (clk_tic-INPUT_CLK);
wire    [ 28 :  0 ] tx_tic = r_tx + inc_tx;
always@(posedge clk)
if(reset)
    r_tx <= 29'b0;
else
    r_tx <= tx_tic;
assign output_clk = ~r_tx[28] & ~reset;
endmodule
