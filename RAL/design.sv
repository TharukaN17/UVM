module top (
    input         pclk, 
    input         presetn, 
    input [31:0]  paddr, 
    input [31:0]  pwdata, 
    input         pwrite, 
    input         psel, 
    input         penable,
    output [31:0] prdata
);
    reg [3:0] cntrl = 0;
    reg [31:0] reg1 = 0;
    reg [31:0] reg2 = 0;
    reg [31:0] reg3 = 0;
    reg [31:0] reg4 = 0;

    reg [31:0] temp_rdata = 0;

    always@(posedge pclk) begin
        if (!presetn) begin
            cntrl <= 4'h0;
            reg1  <= 32'h00000000;
            reg2  <= 32'h00000000;
            reg3  <= 32'h00000000;
            reg4  <= 32'h00000000;
            temp_rdata <= 32'h00000000;
        end else if (psel && penable && pwrite) begin
            case (paddr)
                'h0:  cntrl <= pwdata;
                'h4:  reg1  <= pwdata;
                'h8:  reg2  <= pwdata;
                'hc:  reg3  <= pwdata;
                'h10: reg4  <= pwdata;
            endcase
        end else if (psel && penable && !pwrite) begin
            case (paddr)
                'h0:  temp_rdata <= {28'h0000000, cntrl};
                'h4:  temp_rdata <= reg1;
                'h8:  temp_rdata <= reg2;
                'hc:  temp_rdata <= reg3;
                'h10: temp_rdata <= reg4;
                default: temp_rdata <= 32'h00000000;
            endcase
        end
    end
    assign prdata = temp_rdata;
endmodule

interface top_if;
    logic pclk;
    logic presetn;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic pwrite;
    logic psel;
    logic penable;
    logic [31:0] prdata;
endinterface
