module fft_sdf_stage #(
    parameter WIDTH = 16,      
    parameter DELAY = 128      
)(
    input wire clk,
    input wire rst_n,
    input wire clk_en,         
    input wire phase,   
    // Twiddle factor coefficients
    input signed [WIDTH-1:0] w_re,
    input signed [WIDTH-1:0] w_im,
     
    // Streaming Data Inputs
    input signed [WIDTH-1:0] din_re,
    input signed [WIDTH-1:0] din_im,
    
    // Streaming Data Outputs
    output reg signed [WIDTH-1:0] dout_re,
    output reg signed [WIDTH-1:0] dout_im
);

    // --- 2. Feedback Delay Line Memory (FIFO) ---
    reg signed [WIDTH-1:0] shift_reg_re [0:DELAY-1];
    reg signed [WIDTH-1:0] shift_reg_im [0:DELAY-1];
    
    wire signed [WIDTH-1:0] fifo_out_re = shift_reg_re[DELAY-1];
    wire signed [WIDTH-1:0] fifo_out_im = shift_reg_im[DELAY-1];
    
    reg signed [WIDTH-1:0] fifo_in_re;
    reg signed [WIDTH-1:0] fifo_in_im;
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DELAY; i = i + 1) begin
                shift_reg_re[i] <= 0;
                shift_reg_im[i] <= 0;
            end
        end else if (clk_en) begin
            for (i = DELAY-1; i > 0; i = i - 1) begin
                shift_reg_re[i] <= shift_reg_re[i-1];
                shift_reg_im[i] <= shift_reg_im[i-1];
            end
            shift_reg_re[0] <= fifo_in_re;
            shift_reg_im[0] <= fifo_in_im;
        end
    end
    // --- 3. Arithmetic Butterfly Combinational Core ---
    // FIX: explicit sign-extend before add/sub so growth-by-1-bit isn't
    // truncated by the tool evaluating the sum at 16 bits before the shift.
    reg signed [WIDTH-1:0] bt_x_re, bt_x_im; 
    reg signed [WIDTH-1:0] bt_y_re, bt_y_im; 
    
    always @(*) begin
        bt_x_re = ({fifo_out_re[WIDTH-1], fifo_out_re} + {din_re[WIDTH-1], din_re}) >>> 1;
        bt_x_im = ({fifo_out_im[WIDTH-1], fifo_out_im} + {din_im[WIDTH-1], din_im}) >>> 1;
        
        bt_y_re = ({fifo_out_re[WIDTH-1], fifo_out_re} - {din_re[WIDTH-1], din_re}) >>> 1;
        bt_y_im = ({fifo_out_im[WIDTH-1], fifo_out_im} - {din_im[WIDTH-1], din_im}) >>> 1;
    end
    // --- 4. Inter-Stage Multiplexer Routing ---
    reg signed [WIDTH-1:0] mux_out_re;
    reg signed [WIDTH-1:0] mux_out_im;
    always @(*) begin
        if (phase == 0) begin
            fifo_in_re = din_re;
            fifo_in_im = din_im;
            mux_out_re = fifo_out_re;
            mux_out_im = fifo_out_im;
        end else begin
            fifo_in_re = bt_y_re;
            fifo_in_im = bt_y_im;
            mux_out_re = bt_x_re;
            mux_out_im = bt_x_im;
        end
    end
// --- 5. Complex Twiddle Multiplication Block ---
    // Fix: Use 32767 to represent +1.0 in Q15 to match your Python generation script
    wire signed [WIDTH-1:0] true_w_re = (phase == 0) ? w_re : 16'sd32767; 
    wire signed [WIDTH-1:0] true_w_im = (phase == 0) ? w_im : 16'sd0;

    reg signed [(2*WIDTH)-1:0] mult_re;
    reg signed [(2*WIDTH)-1:0] mult_im;

    always @(*) begin
        mult_re = (mux_out_re * true_w_re) - (mux_out_im * true_w_im);
        mult_im = (mux_out_re * true_w_im) + (mux_out_im * true_w_re);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout_re <= 0;
            dout_im <= 0;
        end else if (clk_en) begin
            dout_re <= mult_re >>> (WIDTH-1);
            dout_im <= mult_im >>> (WIDTH-1);
        end
    end
endmodule

