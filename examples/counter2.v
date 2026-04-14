module counter2(
    input clk,
    output q0,
    output q1
);

    reg q0, q1;

    wire next_q0, next_q1;

    assign next_q0 = ~q0;
    assign next_q1 = q0 ^ q1;

    always @(posedge clk) begin
        q0 <= next_q0;
        q1 <= next_q1;
    end

endmodule
