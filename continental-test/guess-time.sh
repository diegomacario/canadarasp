#!/bin/bash
# Use first command-line argument or the MODEL env var if command-line argument is not defined
MODEL=${1:-$MODEL}
# Use hrdps if neither the command-line argument nor the MODEL env var are defined
MODEL=${MODEL:-"hrdps"}
# Export the MODEL var so that other scripts can use it
export MODEL=$MODEL

# Get current hour in UTC
HR=`date -u +%H`  # takes about 7-9 hours for a run to be complete
# HOUR 00 takes 7 hours to run, so it is ready at 0700 and good until 1300 ... the windgrams don't upload the files in the right place for hour 00
# HOUR 06 takes 7 hours to run, so it is ready at 1300 and good until 1900
# HOUR 12 takes 7 hours to run, so it is ready at 1900 and good until 0000
# HOUR 18 takes 7 hours to run, so it is ready at 0000 and good until 0700 ;; ok, i changed this to be 0000 so we don't have to round back hour=12 too...

ROUNDBACK=0
if [ $MODEL == "gdps" ]; then
  export HOUR=00
else
  # If current hour is >= 0 and <= 7
  if [ $HR -ge 0 -a $HR -le 7 ] ; then
    # We wanna use the data from the run that started at 18Z the previous day
    export HOUR=18 ;
  # If current hour is > 7 and  < 12
  elif [ $HR -gt 7 -a $HR -lt 12 ] ; then
    # We wanna use the data from the run that started at 00Z the same day
    export HOUR=00 ;
  # If current hour is >= 12 and <= 19
  elif [ $HR -ge 12 -a $HR -le 19 ]; then
    # We wanna use the data from the run that started at 06Z the same day
    export HOUR=06;
  else
    # We wanna use the data from the run that started at 12Z the same day
    export HOUR=12;
  fi;

  # The 18Z run started the previous day, so we set ROUNDBACK to true
  if [ $HOUR == 18 ]; then ROUNDBACK=1; fi;
fi

# Guess the day
if [ $ROUNDBACK == 1 ]
   then
   # Use current time minus 9 hours to determine DAY, MONTH and YEAR
   export DAY=`date -u --date="-9 hours" +%d` # at 18 we need to round backwards (run started yesterday)
   export MONTH=`date -u --date="-9 hours" +%m` # at 18 we need to round backwards (run started yesterday)
   export YEAR=`date -u --date="-9 hours" +%Y` # at 18 we need to round backwards (run started yesterday)
   else
   # Use current time to determine DAY, MONTH and YEAR
   export DAY=`date -u +%d` # Otherwise it's today
   export YEAR=`date -u +%Y`
   export MONTH=`date -u +%m`
fi

echo "It is now `date -u`, using data initialized at HOUR $HOUR DAY $DAY MONTH $MONTH YEAR $YEAR from model $MODEL"
