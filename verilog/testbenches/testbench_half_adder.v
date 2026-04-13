module tb_half_adder;
  reg a, b;
  wire sum, carry;

  half_adder uut (.a(a), .b(b), .sum(sum), .carry(carry));

  integer errors = 0;

  initial begin
    a=0; b=0; #10; if (sum!==0 || carry!==0) begin $display("FAIL: 0+0 expected sum=0 carry=0, got sum=%0b carry=%0b", sum, carry); errors=errors+1; end
    a=0; b=1; #10; if (sum!==1 || carry!==0) begin $display("FAIL: 0+1 expected sum=1 carry=0, got sum=%0b carry=%0b", sum, carry); errors=errors+1; end
    a=1; b=0; #10; if (sum!==1 || carry!==0) begin $display("FAIL: 1+0 expected sum=1 carry=0, got sum=%0b carry=%0b", sum, carry); errors=errors+1; end
    a=1; b=1; #10; if (sum!==0 || carry!==1) begin $display("FAIL: 1+1 expected sum=0 carry=1, got sum=%0b carry=%0b", sum, carry); errors=errors+1; end

    if (errors == 0)
      $display("PASS half_adder");
    else
      $display("FAIL half_adder (%0d errors)", errors);
    $finish;
  end
endmodule
