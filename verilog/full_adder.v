module full_adder(
    input a,
    input b,
    input cin,
    output sum, 
    output cout
);

    wire internal1;
    wire internal2;
    wire internal3;

    half_adder half1(
        .a(a),
        .b(b),
        .sum(internal1),
        .carry(internal2)
    );

    half_adder half2(
        .a(internal1),
        .b(cin),
        .sum(sum),
        .carry(internal3)
    );

    assign cout = internal2 | internal3;

endmodule