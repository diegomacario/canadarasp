#!/bin/bash
MODEL=${1:-$MODEL}
DOWNLOADDIRECTORY=$2
source ./model-parameters.sh $MODEL
source ./guess-time.sh $MODEL
echo Cleaning up HGT_SFC mess
HGT_SFC_END=$( filename HGT_SFC_0 $TIMESTOP )
HGT_SFC_ZERO=$( filename HGT_SFC_0 0$TIMESTART )
# HRDPS has HGT_SFC for > 0 only, GDPS has HGT_SFC for 0 only
if [ $MODEL == gdps ]; then # GDPS
 echo Fixing GDPS HGT_SFC to exist always
 TIMEONE=$(( $TIMESTART + $TIMESTEP ))
 GOODTIMES=($(seq -w $TIMEONE $TIMESTEP $TIMESTOP))
 for H in ${GOODTIMES[*]}
 do
  # This generates a symbolic link between the HGT_SFC file at the start time of the forecast and the HGT_SFC file at the forecast time $H.
  # By creating symbolic links between the HGT_SFC files at the start and end times of the forecast,
  # the script is able to ensure that the files exist for all forecast times,
  # even if they were not downloaded directly from the server.
  ln $DOWNLOADDIRECTORY/$HGT_SFC_ZERO $DOWNLOADDIRECTORY/$( filename HGT_SFC_0 $H )
 done
elif [ $MODEL == hrdps_rot ]; then
 echo Fixing HRDPS HGT_SFC to exist always
 ln $DOWNLOADDIRECTORY/$HGT_SFC_END $DOWNLOADDIRECTORY/$HGT_SFC_ZERO
else
 echo Fixing HRDPS HGT_SFC to exist always
 ln $DOWNLOADDIRECTORY/$HGT_SFC_END $DOWNLOADDIRECTORY/$HGT_SFC_ZERO
fi
