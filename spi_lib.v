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

module zrb_spi_rxtx
/*
zrb_spi_rxtx #(8) instance_name
    (
	CLK,
	RESET,
    CLK_EN,
    SPI_IN,
    NEW_DATA,
    [7:0]DATA_IN,
    SPI_OUT,
    [7:0]DATA_OUT,
    CS,
    SCK,
	WRITE_EN,
    READ,
	BUSY,
    START_CLK
	);
*/
	#(parameter NUM_BITS = 8)
	(
	input	wire				clk,
	input	wire				reset,
    input   wire                clk_en,

	input	wire				spi_in,
	input	wire				new_data,
	input	wire	[  NUM_BITS-1 :  0 ] data_in,
    output	wire				spi_out,

	output	wire	[  NUM_BITS-1 :  0 ] data_out,
  	output  wire				cs,
	output	wire				sck,

	output	wire				write_en,
	output	wire				read,
	output	wire				busy,
    output  wire                start_clk
	);

reg     [  3 :  0 ] r_cnt = 4'b0;
reg                 r_rd = 1'b0;
reg                 r_start_clk = 1'b0;
reg     [  7 :  0 ] r_data = 8'b0;
reg                 r_rx = 1'b0;
reg                 r_tx = 1'b0;
reg                 trxing = 1'b0;
reg                 r_wr = 1'b0;

localparam  [  2 :  0 ] IDLE = 3'b000,
                        SET_CLK_RD = 3'b001,
                        NEGEDGE_CLK = 3'b011,
                        POSEDGE_CLK = 3'b010,
                        SET_CLK_WR = 3'b110,
                        TxChkSum = 3'b100;
reg         [  2 :  0 ] r_state = IDLE;

assign              sck = r_state == POSEDGE_CLK;
assign              cs = r_state == IDLE;
assign              busy = 1'b0;
assign              read = r_rd & clk_en;
assign              write_en = ~r_wr & r_state == SET_CLK_WR;
assign              data_out = r_data;
assign              start_clk = r_start_clk;
assign              spi_out = r_tx;


always@(posedge clk)
begin
    r_wr <= 1'b0;
    r_rd <= 1'b0;
    case(r_state)
        IDLE:
            if(clk_en)
                r_state <= SET_CLK_RD;
        SET_CLK_RD:
            if(clk_en)
                r_state <= NEGEDGE_CLK;
        NEGEDGE_CLK:
            if(clk_en)
                r_state <= POSEDGE_CLK;
        POSEDGE_CLK:
            begin
                if(clk_en & r_cnt == 4'd0)
                    r_state <= SET_CLK_WR;
                if(clk_en & r_cnt != 4'd0)
                    r_state <= NEGEDGE_CLK;
            end
        SET_CLK_WR:
            begin
                if(clk_en & new_data)
                    r_state <= NEGEDGE_CLK;
                if(clk_en & ~new_data)
                    r_state <= IDLE;
            end
    endcase

    case(r_state)
        IDLE:
            begin
                r_cnt <= 4'd8;
                r_rd <= 1'b0;
                r_start_clk <= 1'b0;
                if(new_data)
                begin
                    r_data <= data_in;
                    r_start_clk <= 1'b1;
                end
                if(clk_en)
                    r_tx <= r_data[7];
            end
        SET_CLK_RD:
            begin
                if(clk_en)
                    r_cnt <= 4'd8;
                if(new_data)
                    r_rd <= 1'b1;
            end
        NEGEDGE_CLK:
            begin
                r_rd <= 1'b0;
                if(clk_en)
                begin
                    r_cnt <= r_cnt - 1'b1;
                    r_rx <= spi_in;
                end
            end
        POSEDGE_CLK:
            if(clk_en)
            begin
                r_data <= {r_data[6:0], r_rx};
                r_tx <= r_data[6];
            end
        SET_CLK_WR:
            begin
                r_wr <= 1'b1;
                if(clk_en)
                begin
                    r_cnt <= 4'd8;
                    r_tx <= r_data[7];
                end
                if(new_data)
                    r_rd <= 1'b1;
                if(r_rd)
                    r_data <= data_in;
            end
    endcase

end
endmodule

module zrb_sd_core
	#(parameter NUM_BITS = 8)
	(
    input   wire                clk,
    
    input   wire    [  7 :  0 ] data_in,
    input   wire                we,
    input   wire                miso,

    input   wire                tx_fifo_enable,
    output  wire    [  7 :  0 ] data_out,
    output  wire                new_data,
    output  wire                mosi,
    output  wire                ss,
    output  wire                sck
    );

reg         [  7 :  0 ] r_data = 8'b0;
reg         [  3 :  0 ] r_cnt_power_on = 4'b0;
reg                     r_wr = 1'b0;
reg                     r_rd = 1'b0;
localparam  [  4 :  0 ] IDLE =       5'b00000,
                        POWER_ON =   5'b00001,
                        SOFT_RESET = 5'b00010;
reg         [  4 :  0 ] r_state = IDLE;


always@(posedge clk)
begin
    case(r_state)
        IDLE:
            r_state <= POWER_ON;
        POWER_ON:
            if(r_cnt_power_on == 4'd10)
                r_state <= SOFT_RESET;
        SOFT_RESET:
    endcase
    
    case(r_state)
        IDLE:
            r_cnt_power_on <= 4'd0;
        POWER_ON:
            begin
                r_data <= 8'd255;
                r_wr <= 1'b0;
                if(~tx_full)
                begin
                    r_wr <= 1'b1;
                    r_cnt_power_on <= r_cnt_power_on + 1'b1;
                    if(r_cnt_power_on == 7'd127)
                        r_cnt_power_on <= 7'd0;
                end
            end
    endcase
end

zrb_clk_generator #(50000000,10000000) instance_name(clk, reset, low_full_speed, output_clk);

wire [7:0] rx_data;
wire rx_write;
wire rx_busy;
wire rx_full;
wire rx_empty;
zrb_sync_fifo #(2,8) rx_fifo (
    1'b0,
    clk,
    r_wr,
    rx_data,
    RD_EN,
    ,
    rx_full,
    rx_empty
    );
    
wire [7:0] tx_data;
wire tx_write;
wire tx_read;
wire tx_busy;
wire tx_full;
wire tx_empty;
zrb_sync_fifo #(2,8) tx_fifo (
    1'b0,
    clk,
    r_wr,
    r_data,
    RD_EN,
    RD_DATA[7:0],
    FIFO_FULL,
    FIFO_EMPTY
    );

wire    w_rd;
wire    w_wr;
wire    mosi_spi;
wire    miso_spi;
zrb_spi_rxtx #(8) spi
    (
	clk,
	1'b0,
    CLK_EN,
    miso_spi,
    NEW_DATA,
    [7:0]DATA_IN,
    mosi_spi,
    rx_data,
    CS,
    SCK,
	WRITE_EN,
    READ,
	BUSY,
    START_CLK
	);
endmodule


    
