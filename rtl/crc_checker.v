module crc_checker (
    input wire [15:0] crc16,
    input wire [23:0] crc24a,
    input wire [23:0] crc24b,
    input wire [23:0] crc24c,
    output reg error
);

always @(*) begin
    if (crc16 != 16'h0000 ||
        crc24a != 24'h000000 ||
        crc24b != 24'h000000 ||
        crc24c != 24'h000000)
        error = 1;
    else
        error = 0;
end

endmodule
