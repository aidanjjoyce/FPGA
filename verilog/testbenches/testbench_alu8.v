module tb_alu8;
  reg  [7:0] a, b;
  reg  [1:0] op;
  wire [7:0] result;

  alu8 uut (.a(a), .b(b), .op(op), .result(result));

  integer errors = 0;

  task check;
    input [7:0] ea, eb;
    input [1:0] eop;
    input [7:0] expected;
    input [63:0] label; // unused, for readability at call site
    begin
      a=ea; b=eb; op=eop; #10;
      if (result !== expected) begin
        $display("FAIL: a=%0d b=%0d op=%0b expected %0d got %0d", ea, eb, eop, expected, result);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    // ADD (op=00)
    check(8'd12,  8'd7,  2'b00, 8'd19,  0);  // plan milestone: 12+7=19
    check(8'd100, 8'd55, 2'b00, 8'd155, 0);
    check(8'd255, 8'd1,  2'b00, 8'd0,   0);  // overflow wraps

    // SUB (op=01)
    check(8'd20, 8'd4,  2'b01, 8'd16,  0);   // plan milestone: 20-4=16
    check(8'd10, 8'd10, 2'b01, 8'd0,   0);
    check(8'd3,  8'd7,  2'b01, 8'd252, 0);   // wraps unsigned

    // AND (op=10)
    check(8'hFF, 8'h0F, 2'b10, 8'h0F, 0);
    check(8'hAA, 8'h55, 2'b10, 8'h00, 0);

    // OR (op=11)
    check(8'hAA, 8'h55, 2'b11, 8'hFF, 0);
    check(8'h00, 8'hF0, 2'b11, 8'hF0, 0);

    if (errors == 0)
      $display("PASS alu8");
    else
      $display("FAIL alu8 (%0d errors)", errors);
    $finish;
  end
endmodule
