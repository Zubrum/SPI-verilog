module zrb_sd_core
/*
zrb_sd_core #(8) spi_core (
    clk, 
    data_in[7:0], 
    wwe, 
    miso, 
    wrd, 
    data_out, 
    new_data, 
    mosi, 
    ss, 
    sck
    );
*/
    #(parameter NUM_BITS = 8)
    (
    input   wire                clk,
    
    input   wire    [  7 :  0 ] data_in,
    input   wire                wwe,
    input   wire                miso,

    input   wire                wrd,
    output  wire    [  7 :  0 ] data_out,
    output  wire                new_data,
    output  wire                mosi,
    output  wire                ss,
    output  wire                sck
    );

reg         [  7 :  0 ] r_data = 8'd0;
reg         [  7 :  0 ] r_data_out = 8'b0;
reg         [  3 :  0 ] r_cnt_power_on = 4'b0;
reg         [  1 :  0 ] r_wr = 2'b0;
wire                    wr_en = r_wr == 2'b01;
reg         [  1 :  0 ] r_rd = 2'b0;
wire                    rd_en = r_rd == 2'b01;
localparam  [  4 :  0 ] START =      5'b00000,
                        POWER_ON =   5'b00001,
                        SOFT_RESET = 5'b00010,
                        WAIT_RESP =  5'b00100,
                        INIT_SD =    5'b01000,
                        INIT_END =   5'b10000,
                        NORMAL_WORK= 5'b11000;
reg         [  4 :  0 ] r_state = START;
reg         [  7 :  0 ] r_start = 8'd0;
//wire                    w_wr_en = r_wr & ~w_input_full;

wire w_clk_out;
wire w_start_clk;
wire w_ss;
wire w_input_full;
wire w_output_full;
wire w_input_empty;
wire w_output_empty;
wire [2:0] spi_state;
wire [7:0] w_data_out;



zrb_spi_rxtx #(8) spi_rxtx
    (
    clk,
    1'b0,
    w_clk_out,
    miso,
    wr_en,
    r_data,
    mosi,
    rd_en, //read
    w_data_out,
    w_ss,
    sck,
    w_start_clk,
    w_input_full,
    w_output_full,
    w_input_empty,
    w_output_empty,
    spi_state
    );

zrb_clk_generator #(50000000,5000000) spi_clkgen(clk, ~w_start_clk, 1'b1, w_clk_out);


always@(posedge clk)
begin
    r_rd <= {r_rd[0], 1'b0};
    if(~w_output_empty)
    begin
        r_rd <= {r_rd[0], 1'b1};
    end
    if(rd_en)
    begin
        case(r_state)
            WAIT_RESP, INIT_END: r_data_out <= w_data_out;
            default: begin end
        endcase
    end
    
    case(r_state)
        START:
            if(r_start == 8'd255)
                r_state <= POWER_ON;
        POWER_ON:
            if((r_cnt_power_on == 4'd10) & (spi_state == 3'b000))
                r_state <= SOFT_RESET;
        SOFT_RESET:
            if((r_cnt_power_on == 4'd6) & (spi_state == 3'b000))
                r_state <= WAIT_RESP;
        WAIT_RESP: 
            if(r_data_out == 8'd1)
                r_state <= INIT_SD;
            else
            if((r_cnt_power_on == 4'd10) & (spi_state == 3'b000))
                r_state <= POWER_ON;
        INIT_SD:
            if((r_cnt_power_on == 4'd6) & (spi_state == 3'b000))
                r_state <= INIT_END;
        INIT_END:
            if(r_data_out == 8'd0)
                r_state <= NORMAL_WORK;
            else
            if((r_cnt_power_on == 4'd10) & (spi_state == 3'b000))
                r_state <= POWER_ON;
        NORMAL_WORK: begin end
    endcase
    
    case(r_state)
        START:
            begin
                r_start <= r_start + 1'b1;
                r_cnt_power_on <= 4'd0;
                r_wr <= 2'b0;
                r_rd <= 2'b0;
            end
        POWER_ON:
            begin
                r_wr <= {r_wr[0], 1'b0};
                r_data <= 8'd255;
                if((~w_input_full) & (r_wr == 2'b00) & (r_cnt_power_on != 4'd10))
                    r_wr <= {r_wr[0], 1'b1};
                if(r_wr == 2'b10)
                    r_cnt_power_on <= r_cnt_power_on + 1'b1;
                if((r_cnt_power_on == 4'd10) & (spi_state == 3'b000))
                    r_cnt_power_on <= 4'd0;

            end
        SOFT_RESET, INIT_SD:
            begin
                r_wr <= {r_wr[0], 1'b0};
                if(~w_input_full & (r_wr == 2'b00) & (r_cnt_power_on != 4'd6))
                    r_wr <= {r_wr[0], 1'b1};
                if(r_wr == 2'b10)
                    r_cnt_power_on <= r_cnt_power_on + 1'b1;
                if((r_cnt_power_on == 4'd6) & (spi_state == 3'b000))
                    r_cnt_power_on <= 4'd0;

                case(r_cnt_power_on)
                    4'd0: r_data <= r_state == SOFT_RESET ? 8'h40 : 8'h41;
                    4'd1: r_data <= 8'h00;
                    4'd2: r_data <= 8'h00;
                    4'd3: r_data <= 8'h00;
                    4'd4: r_data <= 8'h00;
                    4'd5: r_data <= 8'h95;
                endcase

            end
        WAIT_RESP, INIT_END:
            begin
                r_data <= 8'd255;
                r_wr <= {r_wr[0], 1'b0};
                if(r_state == WAIT_RESP)
                    if((r_data_out != 8'd1) & (spi_state == 3'b000))
                        r_wr <= {r_wr[0], 1'b1};

                if(r_state == INIT_END)
                    if((r_data_out != 8'd0) & (spi_state == 3'b000))
                        r_wr <= {r_wr[0], 1'b1};
                if(r_wr == 2'b10)
                    r_cnt_power_on <= r_cnt_power_on + 1'b1;
                if((r_cnt_power_on == 4'd10) & (spi_state == 3'b000))
                    r_cnt_power_on <= 4'd0;                    
            end

        NORMAL_WORK: begin end
    endcase
end


assign ss = r_state == (START | POWER_ON) ? 1'b1 : 1'b0;
assign data_out = r_data_out;
assign new_data = r_state == NORMAL_WORK;
endmodule
