import numpy as np

# System Specs
fs = 12000       # 12 kHz sampling rate 
N = 256          # FFT points
f1 = 1000        # 1 kHz component
f2 = 5000        # 5 kHz component

# Generate 256 samples
t = np.arange(N)
signal = 0.5 * np.sin(2 * np.pi * f1 * t / fs) + 0.5 * np.sin(2 * np.pi * f2 * t / fs) 

# Scale to 16-bit signed integer (Q1.15 style)
signal_fixed = np.round(signal * 32767).astype(int)

# Write to a file in Hex format for Verilog $readmemh
with open("input_stimulus.txt", "w") as f:
    for val in signal_fixed:
        # Convert negative numbers to 16-bit 2's complement hex
        hex_val = f"{val & 0xFFFF:04X}"
        f.write(f"{hex_val}\n")

print("input_stimulus.txt generated successfully!")
