module fft256_top #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire clk_en,
    
    input signed [WIDTH-1:0] din_re,
    input signed [WIDTH-1:0] din_im,
    
    output reg signed [WIDTH-1:0] dout_re,
    output reg signed [WIDTH-1:0] dout_im,
    output reg out_valid
);
    // --- 1. Frame Counter ---
    reg [7:0] master_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            master_counter <= 0;
        end else if (clk_en) begin
            master_counter <= master_counter + 1;
        end
    end
    // --- 2. Structural Interconnection Busses ---
    wire signed [WIDTH-1:0] stage_re [0:8];
    wire signed [WIDTH-1:0] stage_im [0:8];
    
    assign stage_re[0] = din_re;
    assign stage_im[0] = din_im;

    // FIX: cumulative pipeline latency (in cycles) a sample has already
    // accrued by the time it reaches the INPUT of stage s. Each
    // fft_sdf_stage instance adds exactly (DELAY + 1) cycles of latency
    // -- DELAY cycles for its internal FIFO, +1 for its output register.
    // Stage 0 sees data the same cycle master_counter updates, so it
    // needs zero compensation; every later stage needs its twiddle
    // address generated from master_counter AS IT WAS that many cycles
    // ago, not its current value, or the twiddle factor applied is the
    // one meant for a different (later) sample entirely.
    function integer cum_latency;
        input integer stage;
        integer k;
        integer delay_val;
        begin
            cum_latency = 0;
            delay_val = 128;
            for (k = 0; k < stage; k = k + 1) begin
                cum_latency = cum_latency + delay_val + 1;
                delay_val = delay_val >> 1;
            end
        end
    endfunction

    // --- 3. Parameterized Generation Loop (8 Cascading Stages) ---
    genvar s;
    generate
        for (s = 0; s < 8; s = s + 1) begin : fft_pipeline
            localparam stage_delay = 128 >> s;
            localparam CUM_LAT = cum_latency(s);
            
            wire signed [WIDTH-1:0] t_re, t_im;
            wire [6:0] rom_addr;
            wire [7:0] aligned_counter;

            if (CUM_LAT == 0) begin : no_delay
                // Stage 0: no compensation needed, data arrives same cycle.
                assign aligned_counter = master_counter;
            end else begin : delay_chain
                // Shift register that reproduces master_counter's value
                // from CUM_LAT cycles ago, time-aligning the address
                // generator with the sample actually present at this
                // stage's butterfly/multiplier this cycle.
                reg [7:0] delay_regs [0:CUM_LAT-1];
                integer d;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (d = 0; d < CUM_LAT; d = d + 1)
                            delay_regs[d] <= 8'd0;
                    end else if (clk_en) begin
                        for (d = CUM_LAT-1; d > 0; d = d - 1)
                            delay_regs[d] <= delay_regs[d-1];
                        delay_regs[0] <= master_counter;
                    end
                end
                assign aligned_counter = delay_regs[CUM_LAT-1];
            end

            wire [15:0] shifted_counter = aligned_counter << s;
            assign rom_addr = shifted_counter[6:0];

            twiddle_rom #(.WIDTH(WIDTH), .SIZE(128)) t_rom (
                .clk(clk),
                .addr(rom_addr),
                .w_re(t_re),
                .w_im(t_im)
            );
            fft_sdf_stage #(
                .WIDTH(WIDTH),
                .DELAY(stage_delay)
            ) stage_inst (
                .clk(clk),
                .rst_n(rst_n),
                .clk_en(clk_en),
                .w_re(t_re),
                .w_im(t_im),
                .phase(aligned_counter[7-s]),   
                .din_re(stage_re[s]),
                .din_im(stage_im[s]),
                .dout_re(stage_re[s+1]),
                .dout_im(stage_im[s+1])
            );
        end
    endgenerate
    // --- 4. True Latency Pipeline Validity Tracker ---
    // Unchanged: 264 = sum(DELAY) + 8 stage output regs + 1 output reg.
    // This budget was already correct for data-path latency; the bug
    // fixed above was in the TWIDDLE ADDRESS timing, not the data path,
    // so this counter does not need to change.
    reg [263:0] latency_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_pipe <= 0;
            out_valid    <= 0;
        end else if (clk_en) begin
            latency_pipe <= {latency_pipe[262:0], 1'b1};
            if (latency_pipe[263]) begin
                out_valid <= 1'b1;
            end
        end
    end
    // --- 5. Gated Synchronous Output Assignment ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout_re <= 0;
            dout_im <= 0;
        end else if (clk_en) begin
            if (out_valid) begin
                dout_re <= stage_re[8];
                dout_im <= stage_im[8];
            end else begin
                dout_re <= 0;
                dout_im <= 0;
            end
        end
    end
endmodule
