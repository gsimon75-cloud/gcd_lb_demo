#!/bin/sed -rf
s/\x1b\[[0-9;]*m//g
s/\x08//g
/\[[# ]+\]/d
/(Verifying|Installing|Updating|Cleanup) +: .* +[0-9]+\/[0-9]+$/d
/ \| +[0-9.]+ [kMG]?B +[0-9-]{2}:[0-9-]{2}( (ETA|!!!))?$/d
/Repository '.*' is disabled for this system.$/d
