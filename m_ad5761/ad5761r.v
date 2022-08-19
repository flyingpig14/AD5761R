`timescale 1ns / 1ps
//现在只是做一个ad5761r功能是否正常的测试，固定dac的功能为复位-写入更新-回读，如果后面确实证明原代码有问题，再完善代码合并到原项�?

module AD5761R(
	input			clk,			//50MHz
	input			rst_n,
	input			DAC_ALERT_N,	//活动低报警，短路�?150°以上或欠压时�?0，对控制寄存器的写操作会使其�?1
	input			DAC_DOUT,		//SDO
	output			DAC_DIN,		//SDI
	output			DAC_CS_N,		//片�?�信�?
	output			DAC_SCLK,		//DAC时钟信号
	output			DAC_RESET_N,	//DAC重置信号,低电平有�?
    output			DAC_LOAD_N,		//永久拉低时，更新输入寄存器即更新DAC寄存器，写入输入寄存器时若保持高电平，则不会更新DAC输出寄存�?
	output			DAC_CLEAR_N,	//清除DAC数据

	//串口通信，用来获取回读数�?
    input 			UART_RX,
    output 			UART_TX
);
//reg clk;
//reg rst_n;


reg [15:0]DAC_vout_reg = 16'hFFFF;	//设定的DAC输出
//assign DAC_RESET_N = 1;			//不进行重�?
assign DAC_LOAD_N = 0;			//即时更新DAC_register

//req是否�?要�?�过req1 req0延时�?个clk？，暂时不做
reg DAC_req;
reg [23:0]sdi_data;		//主设备发送给从设备的数据，即对DAC的操作指�?
wire [23:0]sdo_data;	//从设备反馈给主设备的数据，回读操作时接收
wire done;				//DAC�?个指令完�?


/*	DAC功能地址，根据ad5761r的[DB23:DB20]设置，顺序一�?
		NOP1 				= 4'h0;
		Wr_Input_Reg 		= 4'h1;		写入输入寄存�?
		Update_DAC_Reg 		= 4'h2;		更新DAC寄存�?
		Wr_Update_DAC_Reg   = 4'h3;		写入并更新DAC寄存�?
		Wr_Ctrl_Reg 		= 4'h4;		写入控制寄存�?
		NOP2				= 4'h5;
		NOP3				= 4'h6;
		Software_Data_Rst	= 4'h7;		软件控制复位
		Reserved			= 4'h8;	
		Daisy_Chain			= 4'h9;		禁用菊花链功�?
		Rdbak_Input_Reg		= 4'hA;		回读Input
		Rdbak_DAC_Reg		= 4'hB;		回读DAC
		Rdbak_Ctrl_Reg		= 4'hC;		回读Ctrl
		NOP4				= 4'hD;
		NOP5				= 4'hE;
		Software_Full_Rst	= 4'hF;		软件控制完全复位
	NOP1-5相同，回读操作后�?要接�?个NOP，在NOP时接收sdo_data
*/

//DAC状�?�机

//DAC_orders
reg [7:0]dac_order_cnt;
reg [3:0]dac_orders;
reg [31:0]init_cnt;
localparam init_cnt_full = 32'd10_000;
reg [31:0]delay_cnt;
localparam T_100ns = 32'd5_000;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		DAC_req = 0;
		init_cnt = 0;
		delay_cnt = 0;
		dac_order_cnt = 8'd0;
    end
	else begin
		case(dac_order_cnt)
			0:begin
				if(init_cnt >= init_cnt_full)begin
					init_cnt = 0;
					dac_order_cnt = dac_order_cnt + 1;
				end
				else
					init_cnt = init_cnt + 1;
			end
			1,3,5,7,9:begin
				if(done)begin
					DAC_req = 0;
					dac_order_cnt = dac_order_cnt + 1;
				end
				else
					DAC_req = 1;
			end
			2,4,6,8:begin
				if(delay_cnt >= T_100ns)begin
					delay_cnt = 0;
					dac_order_cnt = dac_order_cnt + 1;
				end
				else
					delay_cnt = delay_cnt + 1;
			end
			10:begin
			     DAC_req = 0;
			end
			default:begin
					DAC_req = 0;
					dac_order_cnt = 0;
			end
		endcase
	end
end


//测试DAC，指令依次为写入并更新DAC-回读DAC-NOP
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		dac_orders = 4'b0;
	else begin
		case(dac_order_cnt)
			8'h1:dac_orders = 4'hF;
			8'h3:dac_orders = 4'h4;
			8'h5:dac_orders = 4'h3;
			8'h7:dac_orders = 4'hB;
			8'h9:dac_orders = 4'h0;
			default:dac_orders = 4'h0;
        endcase
	end
end

//sdi_data�?16�?
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		sdi_data[15:0] = 16'b0;
	else begin
		case(dac_order_cnt)
			8'h3:sdi_data[15:0] = 16'h0241;
			8'h5:sdi_data[15:0] = DAC_vout_reg[15:0];
			default:sdi_data[15:0] = 16'h0;
        endcase
	end
end
//sdi_data�?8�?
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		sdi_data[23:16] = 8'b0;
	else
		sdi_data[23:16] = {4'b0,dac_orders[3:0]};
end

//串口发�?�回读数�?

reg [23:0]dac_back_data;
reg uart_tx_req;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		uart_tx_req = 0;
		dac_back_data = 24'h0;
	end
	else begin
		if(dac_order_cnt == 9)
			if(done)begin
				dac_back_data = sdo_data;
				uart_tx_req = 1;
			end
	end
end

spi_core ad5761r_spi(
	.clk(clk),
	.rst_n(rst_n),
	.DAC_DOUT(DAC_DOUT),
	.sdo_data(sdo_data),
	.sdi_data(sdi_data),
	.DAC_DIN(DAC_DIN),
	.DAC_CS_N(DAC_CS_N),
	.DAC_SCLK(DAC_SCLK),
	.DAC_req(DAC_req),
	.DONE(done)
);

UART_TST dac_bak (
    .clk(clk),
    .rst_n(rst_n),
    .UART_RX(UART_RX),
    .UART_TX(UART_TX),
    .dac_back_data(dac_back_data),
    .uart_tx_req(uart_tx_req)
);


/*
initial begin
	rst_n = 1;
	clk = 0;
	dac_order_cnt = 0;
	init_cnt = 0;
	delay_cnt = 0;
	DAC_req = 0;
end
always begin
	#10 clk = ~clk;
end
*/
endmodule
