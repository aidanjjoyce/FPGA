module tb_mux2;
  reg a, b, sel;
  wire y;

  mux2 uut (.a(a), .b(b), .sel(sel), .y(y));

  integer errors = 0;

  initial begin
    // sel=0 → y should be a
    a=0; b=1; sel=0; #10; if (y !== 0) begin $display("FAIL: sel=0,a=0 expected 0 got %0b", y); errors=errors+1; end
    a=1; b=0; sel=0; #10; if (y !== 1) begin $display("FAIL: sel=0,a=1 expected 1 got %0b", y); errors=errors+1; end
    // sel=1 → y should be b
    a=0; b=1; sel=1; #10; if (y !== 1) begin $display("FAIL: sel=1,b=1 expected 1 got %0b", y); errors=errors+1; end
    a=1; b=0; sel=1; #10; if (y !== 0) begin $display("FAIL: sel=1,b=0 expected 0 got %0b", y); errors=errors+1; end

    if (errors == 0)
      $display("PASS mux2");
    else
      $display("FAIL mux2 (%0d errors)", errors);
    $finish;
  end
endmodule
