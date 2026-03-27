import crcmod
import random

# Initializing CRC functions for comparison
# CRC16-CCITT: polynomial=0x11021, initCrc=0xFFFF
crc16_func = crcmod.mkCrcFun(0x11021, initCrc=0xFFFF, rev=False)

def run_golden_model(num_tests=100):
    print(f"Running {num_tests} Golden Model Tests...")
    for i in range(num_tests):
        # Generate 32-bit random data
        data_int = random.getrandbits(32)
        data_bytes = data_int.to_bytes(4, 'big')
        
        # Calculate CRC using crcmod
        crc = crc16_func(data_bytes)
        
        print(f"Test {i}: DATA=0x{data_int:08x} CRC16=0x{crc:04x}")

if __name__ == "__main__":
    run_golden_model()
