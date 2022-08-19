module spi_core(
	input			clk,			//50MHz
	input			rst_n,
	
	input			DAC_DOUT,		//SDO
	output			[23:0]sdo_data,	//接受自从机的数据，由SDO翻译而来
	
	input			[23:0]sdi_data,	//发�?�给从机的数据，转换成SDI
	output			DAC_DIN,		//SDI
	
	output			DAC_CS_N,		//片�?�信�?,0工作
	output			DAC_SCLK,		//DAC时钟信号
	
	input			DAC_req,		//启动DAC
	output			DONE			//完成SDO和SDI数据的转�?
);
parameter bit_length = 24;
reg [4:0]bit_cnt;
reg cs_reg;
reg done;
reg SDI;
reg [23:0]sdo_data_reg;
assign DAC_CS_N = cs_reg;
assign DONE = done;
assign DAC_DIN = SDI;
assign sdo_data = sdo_data_reg;

reg [9:0]sclk_cnt;
reg DAC_SCLK_reg = 0;
assign DAC_SCLK = DAC_SCLK_reg;
//信号定义：上升沿、高电平中间位置、下降沿、低电平中间位置
//注意：HIG和LOW都是中间位置
//SDO在上升沿输出，下降沿有效，因此在NEG读数
//设定SCLK
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		sclk_cnt = 10'd0;
	else if (!cs_reg)begin
		if(sclk_cnt < 10'd999)
			sclk_cnt = sclk_cnt + 1;
		else
			sclk_cnt = 0;
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		DAC_SCLK_reg = 0;
	else
		case(sclk_cnt)
			499:DAC_SCLK_reg = 1;
			999:DAC_SCLK_reg = 0;
			default:;
		endcase
end

`define SCL_LOW		(sclk_cnt == 10'd249)
`define SCL_POS		(sclk_cnt == 10'd499)
`define SCL_HIG		(sclk_cnt == 10'd749)
`define SCL_NEG		(sclk_cnt == 10'd999)

//片�?�信号CS以及读写完成标识
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		cs_reg = 1;
		done = 0;
	end
	else 
		if(DAC_req)begin
			if(bit_cnt <= bit_length - 1)begin
				cs_reg = 0;
				done = 0;
			end
			else if(`SCL_LOW) begin
				cs_reg = 1;
				done = 1;
			end
		end
	else begin
		cs_reg = 1;
		done = 0;
	end
end

//对SDI和SDO赋�??
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)begin
		SDI = 0;
		sdo_data_reg = 24'd0;
		bit_cnt = 5'd0;
	end
	else if(cs_reg)begin
		SDI = 0;
		sdo_data_reg = 24'd0;
		bit_cnt = 5'd0;
	end
	else if(!cs_reg)	begin 
		if(`SCL_POS)
			SDI = sdi_data[bit_length - 1 - bit_cnt];
		if(`SCL_NEG)begin
			sdo_data_reg[bit_length - 1 - bit_cnt] = DAC_DOUT;
			bit_cnt = bit_cnt + 1;
			//�?定要确保先给SDI和sdo_data赋�?�再bit_cnt+1，采用阻塞赋值，而NEG�?定在POS之后
		end
	end
end	

endmodule