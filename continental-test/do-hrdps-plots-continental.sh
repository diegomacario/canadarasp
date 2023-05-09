#!/bin/bash

# Usage:
# ./do-hrdps-plots.sh $YEAR $MONTH $DAY $HOUR
# where $HOUR is 00 or 06 or 12 or 18
# ./generate-hrdps-plots.sh 2013 04 18 06 /mnt/tiles
#  output directory is tiles/-122:-120:49:51/$YEAR-$MONTH-$DAY
#  for each tile longitude / latitude and each year / month / day (local time) in the forecast

# Environment variables
#  NOTILES - skip tile generation
#  NOWINDGRAMS - skip windgrams
#  NOMAP - skip map png generation  
# When this script completes it creates a file /mnt/hrdps-plots-done

echo "$0 $@"
echo "Starting HRDPS plots at `date`"

# The GRIB2TABLE variable specifies the location of the GRIB2 tables that are used to decode the HRDPS data.
# The WGRIB2 variable specifies the location of the wgrib2 utility that is used to extract data from the GRIB2 files.
# The PARALLELSUB, PARALLELTILE, and PARALLELNCL variables specify the number of parallel processes
# that are used for various parts of the script.
# The Z variable is set to the UTC offset.
export GRIB2TABLE=/home/ubuntu/continental-test/grib2tables
WGRIB2=wgrib2
PARALLELSUB=15 # for fixing of file names which doesn't use any internal parallelization of wgrib2
PARALLELTILE=15 # WGRIB2 goes nuts if you set this to more than 1 and don't set OMP_NUM_THREADS=1
PARALLELNCL=14
START_PATH=`pwd`
YEAR=${1:-$YEAR}
MONTH=${2:-$MONTH}
DAY=${3:-$DAY}
HOUR=${4:-$HOUR}  # 06 or 18
# date: This command prints the current date and time.
# +%-:::z: This option specifies the format of the output.
# The %z format specifier is used to print the time zone offset in the format +HHMM or -HHMM.
# The - before the % sign removes leading zeros.
# The + sign is used to indicate that the time zone offset should be printed with a + sign if it is positive.
# If the time zone offset is negative, the - sign is automatically included in the output.
# The ::: characters are used to specify that the output should include colons between the hours and minutes,
# even if the offset is zero.
# The final z character is used to specify that the output should be the time zone offset in hours and minutes.
Z=: This sets the Z variable to the output of the date command.
Z=`date +%-:::z` # This is UTC offset
source ./model-parameters.sh $MODEL
echo "do-hrdps-plots.sh $YEAR-$MONTH-$DAY $HOUR for ${#TIMES[@]} hours, local UTC offset is $Z"

echo "Generating new variables like HCRIT"
./do-generate-new-variables.sh # takes 2 minutes
echo "Done generating new variables"

if [ $MODEL == "hrdps" ]; then
  if [ -z $NOCLIP ]; then
    echo "Starting clipping wind to terrain at `date`"
    ./clip-wind-to-terrain.sh # 4:45 !
    echo "Done clipping wind to terrain at `date`"
  fi
fi

if [ -z $NOTILES ]; then
    echo "Generating tiles at `date`"
    ./do-tile-generation.sh $YEAR $MONTH $DAY $HOUR # takes 27 minutes with new wgrib2
    echo "Done generating tiles at `date`"
fi

if [ -z $NOWINDGRAMS ]; then
    echo "Generating windgrams at `date`"
    ./do-windgrams-continental.sh $YEAR $MONTH $DAY $HOUR # 3 minutes
    echo "Done generating windgrams `date`"
fi

if [ -z $NOMAP ]; then # if string is NULL
    echo "Starting tile graphic generation at `date`"
    FORECASTHOURS=($(seq -w $TIMESTART $TIMESTEP $TIMESTOP))
    echo "Generating headers and footers for all hours starting at `date`"
    ./generate-single-hrdps-plot-continental.lisp --only-generate-header-footer # 3 seconds
    echo "Done generating headers and footers at `date`"
    rm -f /mnt/forecast-hours
    for I in ${FORECASTHOURS[*]}
    do
	echo $I >> /mnt/forecast-hours
    done
    echo "Starting to generate all map pngs at `date`"
    export OMP_NUM_THREADS=1
    parallel --gnu -j 16 ./generate-single-hrdps-plot-continental.lisp {} < /mnt/forecast-hours  # 4 min 10 seconds for j = 16., 5 min for j = 15
    export -n OMP_NUM_THREADS
    # rm /mnt/forecast-hours
    echo "Done tile graphic generation at `date`"
fi

if [ -z $NOUPLOAD ]; then     # if string is NULL
    # copy png images to rasp server. The rasp server connection has been unreliable so each call has been put in a retry loop
    ./upload-map-pngs.sh
fi
echo "Finished with HRDPS plots at `date`"
echo `date` > /mnt/hrdps-plots-done
