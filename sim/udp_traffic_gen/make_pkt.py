from scapy.all import *

pkt = Ether(src="CA:FE:BE:EF:BA:BE", dst="2C:56:DC:9A:EE:60", type=0x800) / IP(src="192.168.1.43", dst="192.168.1.2") / UDP(sport=4346,dport=6789)
for b in raw(pkt):
    print("x\"", end='')
    print(format(int(b), '02x'), end="\", ")
print(len(raw(pkt)))
