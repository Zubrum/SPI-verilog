module zrb_sync_fifo
/*
zrb_sync_fifo #(2,8) instance_name (
    RESET,
    WR_CLK,
    WR_EN,
    WR_DATA[7:0],
    RD_EN,
    RD_DATA[7:0],
    FIFO_FULL,
    FIFO_EMPTY
    );
*/
    #(parameter ADDR_WIDTH = 2, DATA_WIDTH = 8)
    (
    input   wire                            reset,

    input   wire                            clk,
    input   wire                            wr_en,
    input   wire    [ (DATA_WIDTH-1) :  0 ] data_in,

    input   wire                            rd_en,
    output  wire    [ (DATA_WIDTH-1) :  0 ] data_out,

    output  wire                            fifo_full,
    output  wire                            fifo_empty
    );
localparam DEPTH = 1 << ADDR_WIDTH;
reg     [ (ADDR_WIDTH) :  0 ] wr_ptr = {(ADDR_WIDTH+1){1'b0}};
reg     [ (ADDR_WIDTH) :  0 ] rd_ptr = {(ADDR_WIDTH+1){1'b0}};
wire    [ (ADDR_WIDTH-1) :  0 ] wr_loc = wr_ptr[ (ADDR_WIDTH-1) :  0 ];
wire    [ (ADDR_WIDTH-1) :  0 ] rd_loc = rd_ptr[ (ADDR_WIDTH-1) :  0 ];

reg     [ (DATA_WIDTH-1) :  0 ] mem [ (DEPTH-1) :  0 ];

reg full = 1'b0;
reg empty = 1'b0;
assign data_out = mem[rd_loc];
assign fifo_empty = empty;
assign fifo_full = full;

always@(wr_ptr or rd_ptr)
begin
    full <= 1'b0;
    empty <= 1'b0;
    if(wr_ptr[ (ADDR_WIDTH-1) :  0 ] == rd_ptr[ (ADDR_WIDTH-1) :  0 ])
        if(rd_ptr[ADDR_WIDTH] == wr_ptr[ADDR_WIDTH])
            empty <= 1'b1;
        else
            full <= 1'b1;
end

always@(posedge clk or posedge reset)
if(reset)
begin
    wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
    rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
end
else
begin
    if(wr_en & !fifo_full)
    begin
        mem[wr_loc] <= data_in;
        wr_ptr <= wr_ptr + 1'b1;
    end
    
    if(rd_en & !fifo_empty)
        rd_ptr <= rd_ptr + 1'b1;
end
endmodule


module zrb_clk_generator
/*
zrb_clk_generator #(50000000,10000000) instance_name(input_clk, output_clk);
*/
    #(parameter INPUT_CLK = 50000000, parameter OUTPUT_CLK = 10000000)
    (
    input   wire                clk,
    output  wire                output_clk
    );
reg     [ 28 :  0 ] r_tx = 29'b0;
wire    [ 28 :  0 ] inc_tx = r_tx[28] ? (OUTPUT_CLK) : (OUTPUT_CLK-INPUT_CLK);
wire    [ 28 :  0 ] tx_tic = r_tx + inc_tx;
always@(posedge clk)
    r_tx <= tx_tic;
assign output_clk = ~r_tx[28];
endmodule

module spi_lib//zrb_spi_rxtx
/*
zrb_spi_rxtx #(8,0,0) instance_name
	(
	CLK,
	RESET,
	SCK,
	CS,
	SPI_IN,
	DATA_OUT[7:0],
	WRITE_EN,
	BUSY,
	);
*/
	#(parameter NUM_BITS = 8, parameter CPOL = 0, parameter CPHA = 0)
	(
	input	wire				clk,
	input	wire				reset,
	input	wire				sck,
	input	wire				cs,
	input	wire				new_data,
	input	wire				spi_in,
	input	wire	[  NUM_BITS-1 :  0 ] data_in,
	output	wire				spi_out,
	output	wire	[  NUM_BITS-1 :  0 ] data_out,
	output	wire				write_en,
	output	wire				read,
	output	wire				busy
	);

function integer clogb2;
input [31:0] value;
integer i;
begin
clogb2 = 0;
for(i = 0; 2**i < value; i = i + 1)
clogb2 = i + 1;
end
endfunction

localparam CNT = clogb2(NUM_BITS);

reg		[  2 :  0 ] r_sck = 3'b0;
wire				posedge_sck = r_sck[2:1] == 2'b01;
wire				negedge_sck = r_sck[2:1] == 2'b10;
reg		[  1 :  0 ] r_din = 2'b0;
wire				din = r_din[1];
reg		[  2 :  0 ] r_cs = 3'b0;
wire				posedge_cs = r_cs[2:1] == 2'b01;
wire				negedge_cs = r_cs[2:1] == 2'b10;
reg		[ CNT-1 :  0 ] 	r_cnt = {CNT{1'b0}};
wire				receiving = |r_cnt;
reg		[ NUM_BITS-1 :  0 ] r_data_rx = {NUM_BITS{1'b0}};
//----------------------------------------------//
reg					r_rd = 1'b0;
reg		[  1 :  0 ] start_read = 2'b0;
wire				w_rd = start_read == 2'b01;
reg					r_tx = 1'b0;
reg		[ NUM_BITS-1 :  0 ] r_data_tx = {NUM_BITS{1'b0}};

assign busy = receiving;
assign write_en = posedge_cs;
assign read = w_rd;
assign data_out = r_data_rx;
assign spi_out = r_tx;
always@(posedge clk)
if(reset)
begin
end
else
begin
	r_sck <= {r_sck[2:1], sck};
	r_din <= {r_din[0], spi_in};
	r_cs <= {r_cs[2:1], cs};

	if(posedge_cs)
		r_cnt <= {CNT{1'b0}};
	if(negedge_cs)
		r_cnt <= {CNT{1'b1}};

	if(posedge_sck)
	begin
		r_cnt <= r_cnt - 1'b1;
		r_data_rx <= {r_data_rx[(NUM_BITS-2):0], spi_in};
	end
//----------------------------------------------//
	r_rd <= 1'b0;
	start_read <= {start_read[0], r_rd};
	if(new_data & ~busy)
	begin
		r_data_tx <= data_in;
		r_rd <= 1'b1;
	end

	if(negedge_sck)
		{r_data_tx, r_tx} <= {1'b0, r_data_tx};	
end

endmodule

