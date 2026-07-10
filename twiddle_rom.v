module twiddle_rom #(
    parameter WIDTH = 16,
    parameter SIZE = 128
)(
    input wire clk,
    input wire [$clog2(SIZE)-1:0] addr,
    output reg signed [WIDTH-1:0] w_re,
    output reg signed [WIDTH-1:0] w_im
);
    reg [WIDTH-1:0] rom_re [0:SIZE-1];
    reg [WIDTH-1:0] rom_im [0:SIZE-1];

initial begin
    $readmemh("twiddles_re_hex.txt", rom_re);
    $readmemh("twiddles_im_hex.txt", rom_im);
end

    // FIX: Original code registered w_re/w_im on posedge clk, giving the
    // ROM 1 cycle of latency between addr changing and data appearing.
    // But rom_addr in fft256_top is generated COMBINATIONALLY from the
    // current master_counter, and fft_sdf_stage multiplies w_re/w_im
    // against mux_out_re/im from the SAME current cycle. That meant the
    // twiddle factor applied each cycle was actually the one belonging
    // to the previous cycle's address -- every stage was multiplying
    // data against the wrong twiddle coefficient (off-by-one sample
    // index), independent of any other bug in the design.
    //
    // Also, this extra latency was never accounted for in fft256_top's
    // latency_pipe[263:0], which assumes exactly 1 cycle of total delay
    // per stage (sum(DELAY) + 8 stages + 1 output reg = 264).
    //
    // Making the read combinational removes the extra latency entirely,
    // so w_re/w_im line up with addr (and therefore with mux_out_re/im)
    // in the same cycle, and the existing 264-cycle budget in
    // fft256_top stays correct with no other changes required.
    //
    // Note: for a small 128-entry x16-bit table this still synthesizes
    // fine (typically as distributed RAM / LUTs) on FPGA. If you later
    // need this to map to a single-cycle BRAM primitive for area/timing
    // reasons, keep the registered version instead and compensate by
    // adding one extra cycle of latency to fft256_top's latency_pipe
    // (272 total) plus delaying the data path into each stage's
    // multiplier by 1 cycle to re-align it with the ROM's registered
    // output.
    always @(*) begin
        w_re = rom_re[addr];
        w_im = rom_im[addr];
    end
endmodule