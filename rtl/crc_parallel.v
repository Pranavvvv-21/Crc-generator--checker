module crc16_parallel (
    input wire clk,
    input wire rst,
    input wire valid,
    input wire [7:0] data_in,
    output reg [15:0] crc
);

integer i;
reg [15:0] next;

always @(posedge clk or posedge rst) begin
    if (rst)
        crc <= 16'hFFFF;
    else if (valid) begin
        next = crc;
        for (i = 0; i < 8; i = i + 1) begin
            if ((next[15] ^ data_in[7-i]) == 1)
                next = (next << 1) ^ 16'h1021;
            else
                next = next << 1;
        end
        crc <= next;
    end
end

endmodule
