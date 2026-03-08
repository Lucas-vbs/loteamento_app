import struct

with open('assets/images/map.png', 'rb') as f:
    f.seek(16)
    width, height = struct.unpack('>II', f.read(8))
    print(f"Dimensions: {width}x{height}")
    print(f"AspectRatio: {width/height}")
