import numpy as np

N = 256
NUM_TWIDDLES = N // 2  # 128 unique coefficients needed

# Open files to save the Hex outputs
with open("twiddles_re_hex.txt", "w") as f_re, open("twiddles_im_hex.txt", "w") as f_im:
    for k in range(NUM_TWIDDLES):
        # Compute real and imaginary components of the exponential rotation
        theta = -2 * np.pi * k / N
        w_real = np.cos(theta)
        w_imag = np.sin(theta)
        
        # Convert to Q1.15 fixed-point format (scale by 2^15 - 1)
        # 1.0 becomes 32767, -1.0 becomes -32768
        q_real = int(round(w_real * 32767))
        q_imag = int(round(w_imag * 32767))
        
        # Bound within 16-bit signed limits defensively
        q_real = max(min(q_real, 32767), -32768)
        q_imag = max(min(q_imag, 32767), -32768)
        
        # Convert to 4-character 2's complement Hex values
        hex_real = f"{q_real & 0xFFFF:04X}"
        hex_imag = f"{q_imag & 0xFFFF:04X}"
        
        f_re.write(f"{hex_real}\n")
        f_im.write(f"{hex_imag}\n")

print("Generated twiddles_re_hex.txt and twiddles_im_hex.txt successfully!")
