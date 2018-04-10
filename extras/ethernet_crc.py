# Calculate the FCS for an Ethernet Frame

import zlib

ETHERNET_FRAME_SIZE = 60

data = '\xff\xff\xff\xff\xff\xff\xde\xad\xbe\xef\xba\x5e\xbe\xef\x68\x65\x6c\x6c\x6f\x20\x77\x6f\x72\x6c\x64'

print ("\nData Length: %d" % len(data))
print ("Data:"),

for byte in data:
    print('%02X' % ord(byte)),

print ("\n\nPadding Length: %d" % (ETHERNET_FRAME_SIZE - len(data)))
for i in range(0,ETHERNET_FRAME_SIZE - len(data)):
    data += '\x00'


print ("\nEthernet FCS:")
# write FCS
crc = zlib.crc32(data)&0xFFFFFFFF
for i in range(4):
    b = (crc >> (8*i)) & 0xFF
    print('%02X' % b),
