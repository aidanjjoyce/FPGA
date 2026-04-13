module tb_dff;
  reg clk, rst, d;
  wire q;

  dff uut (.clk(clk), .rst(rst), .d(d), .q(q));

  integer errors = 0;

  // 10ns clock period
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    // Reset holds q=0
    rst=1; d=1; #12;  // posedge at t=5, t=15...
    @(posedge clk); #1;
    if (q !== 0) begin $display("FAIL: rst=1 expected q=0 got %0b", q); errors=errors+1; end

    // Release reset, d=1 → q should latch 1 on next posedge
    rst=0; d=1;
    @(posedge clk); #1;
    if (q !== 1) begin $display("FAIL: d=1 expected q=1 got %0b", q); errors=errors+1; end

    // d=0 → q should latch 0 on next posedge
    d=0;
    @(posedge clk); #1;
    if (q !== 0) begin $display("FAIL: d=0 expected q=0 got %0b", q); errors=errors+1; end

    // q should not change between clock edges
    d=1; #3;
    if (q !== 0) begin $display("FAIL: q changed outside clock edge"); errors=errors+1; end

    if (errors == 0)
      $display("PASS dff");
    else
      $display("FAIL dff (%0d errors)", errors);
    $finish;
  end
endmodule
