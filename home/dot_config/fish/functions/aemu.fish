function aemu --description "Boot the Pixel_10 Android emulator in the background"
    command emulator -avd Pixel_10 \
        -dns-server 1.1.1.1,8.8.8.8 \
        -gpu host \
        -memory 4096 \
        -cores 4 \
        -no-boot-anim \
        -no-audio \
        -camera-back none -camera-front none \
        -netdelay none -netspeed full \
        -no-snapshot-save \
        -no-metrics \
        $argv &>"$TMPDIR/aemu.log" &
    disown
end
