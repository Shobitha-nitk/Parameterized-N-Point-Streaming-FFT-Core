import numpy as np
import matplotlib.pyplot as plt

def bit_reverse(index, bits=8):
    """Reverses the bits of an integer for an N-bit indexing window."""
    return int(f"{index:0{bits}b}"[::-1], 2)

# --- 1. Load and Parse the Hardware Output File Defensively ---
real_parts = []
imag_parts = []
try:
    with open("output_results.txt", "r") as f:
        for line in f:
            cleaned = line.strip()
            # Skip empty lines or any remaining uninitialized simulation flags
            if not cleaned or any(char in cleaned.lower() for char in ['x', 'u', 'z']):
                continue

            parts = cleaned.split()
            if len(parts) == 2:
                real_parts.append(int(parts[0]))
                imag_parts.append(int(parts[1]))
except FileNotFoundError:
    print("Error: 'output_results.txt' not found.")
    print("Ensure this script is running in the same directory as your simulation output file.")
    exit()

# --- 2. Verify Frame Size and Isolate the First 256-Point Block ---
if len(real_parts) < 256:
    print(f"Error: Only found {len(real_parts)} valid data points.")
    print("A 256-point streaming architecture requires at least one complete 256-point frame.")
    exit()
else:
    print(f"Success: Extracting the first hardware frame (Offset: 0)...")
    real_frame = np.array(real_parts[0:256])
    imag_frame = np.array(imag_parts[0:256])

# --- 3. Undo the Hardware Bit-Reversal Permutation ---
ordered_magnitude = np.zeros(256)
for i in range(256):
    rev_idx = bit_reverse(i, bits=8)
    # Calculate standard magnitude: sqrt(Real^2 + Imag^2)
    ordered_magnitude[i] = np.sqrt(real_frame[rev_idx]**2 + imag_frame[rev_idx]**2)

# --- 4. Define Audio Frequency Bins ---

fs = 12000  # True sampling rate used to generate the test signal
frequencies = np.fft.fftfreq(256, 1/fs)

# --- 5. Generate the Discrete Stem Plot ---
plt.figure(figsize=(12, 5))
# Plot the positive spectrum (Bins 0 to 127 map from 0 Hz up to Nyquist at 6 kHz)
markerline, stemlines, baseline = plt.stem(
    frequencies[:128],
    ordered_magnitude[:128],
    linefmt='b-',      # Solid blue lines for the stems
    markerfmt='bo',    # Blue circles for the discrete bin peaks
    basefmt='k-'       # Black line for the zero baseline
)
# Optimize stem line properties for report-grade clarity
plt.setp(stemlines, 'linewidth', 1.0)
plt.setp(markerline, 'markersize', 4)



# Chart Formatting
plt.title("256-Point Streaming SDF FFT - Discrete Hardware Bin Spectrum", fontsize=14, fontweight='bold', pad=15)
plt.xlabel("Frequency Bins (Hz)", fontsize=12, labelpad=10)
plt.ylabel("Linear Fixed-Point Magnitude", fontsize=12, labelpad=10)
plt.xlim(-250, 6250)
plt.grid(True, linestyle=':', alpha=0.6)
plt.tight_layout()
plt.show()
