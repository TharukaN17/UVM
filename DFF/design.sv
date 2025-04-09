 module dff
  (
    input clk, rst, din,
    output reg dout
  );

  always@(posedge clk)
    begin
      if(rst == 1'b1)
        dout <= 1'b0;
      else
        dout <= din;
    end

endmodule

interface dff_if();
  logic clk;
  logic rst;
  logic din;
  logic dout;
endinterface
