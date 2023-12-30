###############################################################################
# Energy saving                                                               #
###############################################################################

# TODO(env): check based on target machine (MacBook vs Desktop)
# Enable lid wakeup
sudo pmset -a lidwake 1

# Restart automatically on power loss
sudo pmset -a autorestart 1

# Restart automatically if the computer freezes
# sudo systemsetup -setrestartfreeze on

# Sleep the display after 60 minutes
sudo pmset -a displaysleep 60

# Disable machine sleep while charging
# sudo pmset -c sleep 0

# Set machine sleep to 20 minutes on battery
sudo pmset -b sleep 20

# Set standby delay to 24 hours (default is 1 hour)
sudo pmset -a standbydelay 86400

# Never go into computer sleep mode
# sudo systemsetup -setcomputersleep Off > /dev/null

# Hibernation mode
# 0: Disable hibernation (speeds up entering sleep mode)
# 3: Copy RAM to disk so the system state can still be restored in case of a
#    power failure.
sudo pmset -a hibernatemode 0

# Disable autopoweroff: This is a form of hibernation
sudo pmset autopoweroff 0

# Disable powernap: Used to periodically wake the machine for network, and updates(but not the display)
sudo pmset powernap 0

# Disable standby: Used as a time period between sleep and going into hibernation
sudo pmset standby 0

# Disable wake from iPhone/Watch: Specifically when your iPhone or Apple Watch come near, the machine will wake
sudo pmset proximitywake 0

# Disable TCP Keep Alive mechanism to prevent wake ups every 2 hours
# Should be kept disabled only on my iMac
# sudo pmset tcpkeepalive 0