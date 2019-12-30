remote_id=$(
  xinput list |
  sed -n 's/.*Naga.*id=\([0-9]*\).*keyboard.*/\1/p'
)
[ "$remote_id" ] || exit

mkdir -p /tmp/xkb/symbols
cat >/tmp/xkb/symbols/custom <<\EOF
xkb_symbols "remote" {
    key <AE01>   {      [0x006d]       };
    key <AE02>   {      [0x0065]       };
    key <AE03>   {      [0x0072]       };
    key <AE04>   {      [0x0078]       };
    key <AE05>   {      [0x0076]       };
    key <AE06>   {      [0x0064]       };
    key <AE07>   {      [0x002b]       };
    key <AE08>   {      [0x002d]       };
    key <AE09>   {      [0x002f]       };
    key <AE10>   {      [0xff0d]       };
    key <AE11>   {      [0xff1b]       };
    key <AE12>   {      [0xffff]       };
};
EOF

setxkbmap -device $remote_id -print | sed 's/\(xkb_symbols.*\)"/\1+custom(remote)"/' | xkbcomp -I/tmp/xkb -i $remote_id -synch - $DISPLAY 2>/dev/null 

#e    1 0x0065
#m   2 0x006d
#r     3 0x0072
#x     4
#v     5
#d     6
#+    7
#-     8
#/     9
#Enter
#Escape
#Delete