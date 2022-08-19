module UART_TST(
	input clk,
    input rst_n,
    input UART_RX,
    input [23:0]dac_back_data,
    output UART_TX,
    input uart_tx_req

 );
reg [7:0]tx_data;
reg tx_req;
reg [23:0]tx_cnt;
reg [1:0]dac_byte_cnt = 0;
//测试的时候没管tx_done因为50_000个clk后假定已经done了


always@(posedge clk)begin
	if(uart_tx_req)begin
    	if(tx_cnt >= 100_000)begin
    		tx_cnt = 0;
        	if(dac_byte_cnt <2'd3)begin
	        	tx_req = 1;
                case(dac_byte_cnt)
                	2:tx_data = dac_back_data[7:0];
                    1:tx_data = dac_back_data[15:8];
                    0:tx_data = dac_back_data[23:16];
                    default:tx_data = 0;
                endcase 
                dac_byte_cnt = dac_byte_cnt + 1;
        	end
    	end
    	else if(tx_cnt >= 50_000)begin
    		tx_cnt = tx_cnt + 1;
        	tx_req = 0;
    	end
    	else
    		tx_cnt = tx_cnt + 1;
    end    
end

initial begin
	tx_req = 0;
    tx_cnt = 0;
    //tx_data = 8'h55;
end
UART #(
	.CLK_FREQ(50_000_000),
	.BAUD_RATE(115_200)
	)uart_0(
	.iCLK(clk),
	.iRST_N(rst_n),
	.iRX(UART_RX),
	.oTX(UART_TX),
	.oR(rx_done),
	.oT(tx_done),
	.iT(tx_req),
	.iTDATA(tx_data),
	.oRDATA(rx_data)
);
endmodule
