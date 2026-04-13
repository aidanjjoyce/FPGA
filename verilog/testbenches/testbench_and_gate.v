module tb_and_gate;
  reg a, b;
  wire y;

  and_gate uut (.a(a), .b(b), .y(y));

  integer errors = 0;

  initial begin
    a=0; b=0; #10; if (y !== 0) begin $display("FAIL: 0&0 expected 0 got %0b", y); errors=errors+1; end
    a=0; b=1; #10; if (y !== 0) begin $display("FAIL: 0&1 expected 0 got %0b", y); errors=errors+1; end
    a=1; b=0; #10; if (y !== 0) begin $display("FAIL: 1&0 expected 0 got %0b", y); errors=errors+1; end
    a=1; b=1; #10; if (y !== 1) begin $display("FAIL: 1&1 expected 1 got %0b", y); errors=errors+1; end

    if (errors == 0)
      $display("PASS and_gate");
    else
      $display("FAIL and_gate (%0d errors)", errors);
    $finish;
  end
endmodule
