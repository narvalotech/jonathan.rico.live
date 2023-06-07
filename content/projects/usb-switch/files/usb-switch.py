#!/usr/bin/env python3

import hid
import time

print("open hid device")
h = hid.device()
h.open(0x1915, 0x1337)

print(h.get_manufacturer_string())
print(h.get_product_string())
print(h.get_serial_number_string())

h.set_nonblocking(0)

print("turn off..")
h.write([1, 0, 0])
time.sleep(2)
print("turn on..")
h.write([1, 0, 1])

h.close()
