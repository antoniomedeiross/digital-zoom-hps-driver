module clk_divider (
    input wire clk_in,    // Clock de entrada (50 MHz)
    output wire clk_out   // Clock de saída (25 MHz)
);

    reg clk_out_reg = 0;

    always @(posedge clk_in) begin
        clk_out_reg <= ~clk_out_reg;
    end

    assign clk_out = clk_out_reg;

endmodule
