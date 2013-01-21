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
    READ_DATA,
    [7:0]DATA_OUT,
    CS,
    SCK,
    START_CLK,
    INPUT_FULL,
    OUTPUT_FULL,
    INPUT_EMPTY,
    OUTPUT_EMPTY,
    RXTX_STATE
    );
*/
    #(parameter NUM_BITS = 8)
    (
    input   wire                clk,
    input   wire                reset,
    input   wire                clk_en,

    input   wire                spi_in,
    input   wire                new_data,
    input   wire    [  NUM_BITS-1 :  0 ] data_in,
    output  wire                spi_out,

    input   wire                read_imp,
    output  wire    [  NUM_BITS-1 :  0 ] data_out,
    output  wire                cs,
    output  wire                sck,

    output  wire                start_clk,
    output  wire                spi_input_full,
    output  wire                spi_output_full,
    output  wire                spi_input_empty,
    output  wire                spi_output_empty,
    output  wire    [  2 :  0 ] spi_state
    
    );

reg     [  3 :  0 ] r_cnt = 4'b0;
reg                 r_rd = 1'b0;
reg                 r_start_clk = 1'b0;
reg     [  7 :  0 ] r_data = 8'b0;
reg                 r_rx = 1'b0;
reg                 r_tx = 1'b0;
reg                 r_wr = 1'b0;

localparam  [  2 :  0 ] IDLE = 3'b000,
                        SET_CLK_RD = 3'b001,
                        NEGEDGE_CLK = 3'b011,
                        POSEDGE_CLK = 3'b010,
                        SET_CLK_WR = 3'b110,
                        TxChkSum = 3'b100;
reg         [  2 :  0 ] r_state = IDLE;

wire                read = r_rd & clk_en;
wire                write_en = ~r_wr & r_state == SET_CLK_WR;

wire [7:0] w_din;
wire rx_full;
wire rx_empty;
zrb_sync_fifo #(2,8) input_fifo (
    1'b0,
    clk,
    new_data,
    data_in,
    read,
    w_din,
    rx_full,
    rx_empty
    );
    
wire tx_full;
wire tx_empty;
zrb_sync_fifo #(2,8) output_fifo (
    1'b0,
    clk,
    write_en,
    r_data,
    read_imp,
    data_out,
    tx_full,
    tx_empty
    );

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
                if(clk_en & ~rx_empty)
                    r_state <= NEGEDGE_CLK;
                if(clk_en & rx_empty)
                    r_state <= IDLE;
            end
    endcase

    case(r_state)
        IDLE:
            begin
                r_cnt <= 4'd8;
                r_rd <= 1'b0;
                r_start_clk <= 1'b0;
                if(~rx_empty)
                begin
                    r_data <= w_din;
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
                if(~rx_empty)
                    r_rd <= 1'b1;
                if(r_rd)
                    r_data <= w_din;
            end
    endcase
end


assign              sck = r_state == POSEDGE_CLK;
assign              cs = r_state == IDLE;
//assign              data_out = r_data;
assign              start_clk = r_start_clk;
assign              spi_out = r_tx;
assign              spi_input_full = rx_full;
assign              spi_output_full = tx_full;
assign              spi_input_empty = rx_empty;
assign              spi_output_empty = tx_empty;
assign              spi_state = r_state;

endmodule
