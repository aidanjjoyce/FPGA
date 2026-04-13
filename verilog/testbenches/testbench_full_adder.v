module tb_full_adder;
  reg a, b, cin;
  wire sum, cout;

  full_adder uut (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

  integer errors = 0;

  task check;
    input ea, eb, ecin, esum, ecout;
    begin
      a=ea; b=eb; cin=ecin; #10;
      if (sum !== esum || cout !== ecout) begin
        $display("FAIL: a=%0b b=%0b cin=%0b expected sum=%0b cout=%0b got sum=%0b cout=%0b",
                 ea, eb, ecin, esum, ecout, sum, cout);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    check(0,0,0, 0,0);
    check(0,0,1, 1,0);
    check(0,1,0, 1,0);
    check(0,1,1, 0,1);
    check(1,0,0, 1,0);
    check(1,0,1, 0,1);
    check(1,1,0, 0,1);
    check(1,1,1, 1,1);

    if (errors == 0)
      $display("PASS full_adder");
    else
      $display("FAIL full_adder (%0d errors)", errors);
    $finish;
  end
endmodule
