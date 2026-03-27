`timescale 1ns/1ps
module tb_crc;

reg clk, rst, start;
reg [31:0] data;

wire [15:0] crc16;
wire [23:0] crc24a, crc24b, crc24c;
wire error;

integer i;

crc_top uut (
    .clk(clk), .rst(rst), .start(start), .data(data),
    .crc16(crc16), .crc24a(crc24a), .crc24b(crc24b), .crc24c(crc24c)
);

crc_checker chk (
    .crc16(crc16), .crc24a(crc24a), .crc24b(crc24b), .crc24c(crc24c), .error(error)
);

always #5 clk = ~clk;

initial begin
    clk = 0; rst = 1; start = 0; data = 0;
    #20 rst = 0;

    for (i = 0; i < 2000; i = i + 1) begin
        @(posedge clk);
        data = $random;
        start = 1;

        @(posedge clk);
        start = 0;

        repeat (40) @(posedge clk);

        $display("Test %0d | Data=%h | CRC16=%h | CRC24A=%h CRC24B=%h CRC24C=%h | Error=%b",
            i, data, crc16, crc24a, crc24b, crc24c, error);
    end

    $display("==== ALL TESTS DONE ====");
    $finish;
end

endmodule
