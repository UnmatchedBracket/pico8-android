LD_PRELOAD=./picoshim.so ../pico8_64 -width 128 -height 128 -windowed 1 $@ &
(sleep 1; ((cat /tmp/pico8_out | ncat -lk 0.0.0.0 18080) > /tmp/pico8_in ))
