"""
Send raw ethernet packets

Usage:

$ sudo python send_ethernet.py

"""

from socket import *

def sendeth(src, dst, eth_type, payload, interface = "eth0"):

  s = socket(AF_PACKET, SOCK_RAW)

  s.bind((interface, 0))
  return s.send(src + dst + eth_type + payload)

if __name__ == "__main__":
  print("Sent %d-byte Ethernet packet on eth0" %
    sendeth("\xFF\xFF\xFF\xFF\xFF\xFF",
            "\xDE\xAD\xBE\xEF\xBA\x5E",
            "\xBE\xEF",
            "hello world"))
