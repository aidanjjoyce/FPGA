module tb_counter4;
  reg clk, rst;
  wire [3:0] count;

  counter4 uut (.clk(clk), .rst(rst), .count(count));

  integer errors = 0;
  integer i;

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    // Reset → count should be 0
    rst=1;
    @(posedge clk); #1;
    if (count !== 0) begin $display("FAIL: rst=1 expected count=0 got %0d", count); errors=errors+1; end

    rst=0;
    // Clock 16 times and check it increments and wraps
    for (i = 0; i < 16; i = i+1) begin
      @(posedge clk); #1;
      if (count !== (i+1) % 16) begin
        $display("FAIL: step %0d expected count=%0d got %0d", i, (i+1)%16, count);
        errors=errors+1;
      end
    end

    if (errors == 0)
      $display("PASS counter4");
    else
      $display("FAIL counter4 (%0d errors)", errors);
    $finish;
  end
endmodule
