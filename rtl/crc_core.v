module crc_core #(
    parameter WIDTH = 16,
    parameter POLY  = 16'h1021,
    parameter INIT  = {WIDTH{1'b1}}
)(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire data_in,
    output reg  [WIDTH-1:0] crc
);

always @(posedge clk or posedge rst) begin
    if (rst)
        crc <= INIT;
    else if (valid)
        crc <= next_crc(data_in, crc);
end

function [WIDTH-1:0] next_crc;
    input data_bit;
    input [WIDTH-1:0] crc_reg;
    reg feedback;
    reg [WIDTH-1:0] temp;
begin
    feedback = crc_reg[WIDTH-1] ^ data_bit;
    temp = {crc_reg[WIDTH-2:0], 1'b0};

    if (feedback)
        temp = temp ^ POLY;

    next_crc = temp;
end
endfunction

endmodule
