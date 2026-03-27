module crc_top (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] data,

    output wire [15:0] crc16,
    output wire [23:0] crc24a,
    output wire [23:0] crc24b,
    output wire [23:0] crc24c
);

reg [5:0] bit_cnt;
reg [31:0] shift_reg;
reg processing;

wire data_bit = shift_reg[31];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        bit_cnt <= 0;
        shift_reg <= 0;
        processing <= 0;
    end else begin
        if (start) begin
            shift_reg <= data;
            bit_cnt <= 0;
            processing <= 1;
        end else if (processing) begin
            shift_reg <= shift_reg << 1;
            bit_cnt <= bit_cnt + 1;

            if (bit_cnt == 31)
                processing <= 0;
        end
    end
end

crc_core #(.WIDTH(16), .POLY(16'h1021)) CRC16 (
    .clk(clk), .rst(rst), .valid(processing), .data_in(data_bit), .crc(crc16)
);

crc_core #(.WIDTH(24), .POLY(24'h864CFB)) CRC24A (
    .clk(clk), .rst(rst), .valid(processing), .data_in(data_bit), .crc(crc24a)
);

crc_core #(.WIDTH(24), .POLY(24'h800063)) CRC24B (
    .clk(clk), .rst(rst), .valid(processing), .data_in(data_bit), .crc(crc24b)
);

crc_core #(.WIDTH(24), .POLY(24'h4C11DB)) CRC24C (
    .clk(clk), .rst(rst), .valid(processing), .data_in(data_bit), .crc(crc24c)
);

endmodule
