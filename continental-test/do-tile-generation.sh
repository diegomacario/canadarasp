#!/bin/bash

# Usage:
# ./do-tile-generation.sh $YEAR $MONTH $DAY $HOUR
# where $YEAR $MONTH $DAY are forecast date (UTC) $HOUR is 00, 06, 12 or 18 forecast hour (UTC)
# outputs tiles to tiles/lon1:lon2:lat1:lat2/

# Environmental options
#  NOCLIP  - don't clip terrain
#  NOFIX   - don't fix labels on TGL_120 and TGL_40
#  NOTILES - don't generate tiles/ output

echo "$0 $@"
echo "Starting TILE GENERATION at `date`"
export GRIB2TABLE=/home/ubuntu/continental-test/grib2tables
WGRIB2=wgrib2
PARALLELSUB=15 # for fixing of file names which doesn't use any internal parallelization of wgrib2
PARALLELTILE=15 # WGRIB2 goes nuts if you set this to more than 1 and don't set OMP_NUM_THREADS=1
PARALLELNCL=14
NOCLIP=1 # we don't need to clip... not used for windgrams
START_PATH=`pwd`
YEAR=${1:-$YEAR}
MONTH=${2:-$MONTH}
DAY=${3:-$DAY}
HOUR=${4:-$HOUR}
source ./model-parameters.sh $MODEL

echo "Generating tiles from $YEAR-$MONTH-$DAY for ${#TIMES[@]} hours"

# This line sets the number of OpenMP threads to 1.
export OMP_NUM_THREADS=1

# Fixing takes 20 seconds
if [ -z $NOFIX ] ; then
    echo FIXING files starts at `date`
    # fix level info for TGL files

    # This line sets the FILES variable to an array of GRIB2 files that contain the TGL_120 level information.
    FILES=( $OUTPUTDIR/*TGL_120*.grib2 )
    echo "Fixing TGL_120 level on ${#FILES[@]} files"

    # This line removes any existing paralleljobs file.
    rm -f /mnt/paralleljobs

    # This line generates a list of wgrib2 commands that fix the TGL_120 level information in the GRIB2 files
    # and writes them to the paralleljobs file.
    # When you use ${ARRAY[@]} syntax, Bash expands the array elements as separate words,
    # which can be used as arguments to a command or as separate variables.
    # The $ sign is used to expand variables. When you use ${VARIABLE} syntax, Bash expands the VARIABLE variable.
    # The curly braces are used to delimit the variable name and to disambiguate the variable name from surrounding text.
    for F in ${FILES[@]}
    do
    # -v0 sets verbosity to 0, so wgrib2 won't print anything to the console
    # $F contains the path to the input GRIB2 file
    # -set_grib_type c2 sets the GRIB2 product type to c2, which is the code for a surface analysis product
    # -set_lev \"120 m above ground\" sets the level information to 120 meters above ground level
    # -grib_out $F.fixed specifies the output file name and format. The output file name is the same as the input file name,
    # with the .fixed suffix added to it.
	echo $WGRIB2 -v0 $F -set_grib_type c2 -set_lev \"120 m above ground\" -grib_out $F.fixed >> /mnt/paralleljobs
    done

    # This line runs the wgrib2 commands in parallel using the parallel command and the PARALLELSUB variable
    # to specify the number of parallel jobs.
    parallel --gnu -j $PARALLELSUB < /mnt/paralleljobs

    # This line renames the fixed files to their original names.
    for F in ${FILES[@]}
    do
	mv $F.fixed $F
    done

    # This line sets the FILES variable to an array of GRIB2 files that contain the TGL_40 level information.
    FILES=( $OUTPUTDIR/*TGL_40*.grib2 )
    echo "Fixing TGL_40 levels on ${#FILES[@]} files"

    # This line removes any existing paralleljobs file.
    rm -f /mnt/paralleljobs

    # This line generates a list of wgrib2 commands that fix the TGL_40 level information in the GRIB2 files
    # and writes them to the paralleljobs file.
    for F in ${FILES[@]}
    do
	echo $WGRIB2 $F -v0 -set_grib_type c2 -set_lev \"40 m above ground\" -grib_out $F.fixed >> /mnt/paralleljobs
    done
    
    # This line runs the wgrib2 commands in parallel using the parallel command and the PARALLELSUB variable
    # to specify the number of parallel jobs.
    parallel --gnu -j $PARALLELSUB < /mnt/paralleljobs

    # This line renames the fixed files to their original names.
    for F in ${FILES[@]}
    do
	mv $F.fixed $F
    done

    echo FIXING files ends at `date`
fi

# This line unsets the OMP_NUM_THREADS variable.
export -n OMP_NUM_THREADS

# Generate the output directories for the windgram tile grib files
if [ -z $NOTILES ]; then
    echo "Generating output directories"
    # This line creates directories based on the output of a Lisp script
    # The | symbol redirects the output of the required-tiles.lisp command to the xargs command.
    # xargs reads items from standard input and executes a command for each item.
    # -d \\n specifies the delimiter used to separate items in the input. In this case,
    # the delimiter is a newline character (\n).
    # mkdir -p creates directories recursively. The -p option tells mkdir to create parent directories as needed.
    ./required-tiles.lisp | xargs -d \\n mkdir -p
fi

# Generate a command list for wgrib2 that cuts the original data files into tiles
# and then run the commands
if [ -z $NOTILES ]; then
    # The tiles will be generated actually 10% larger than required in the east west direction, and then we will clip by 10%.  This lets us ignore the rotated grid for all the lat/lons we care about.
    # Takes 5 seconds to generate commands
   echo "Generating commands for generating windgram tiles starts at `date`"

   # Remove parallel-jobs file and args file
   rm -f /mnt/parallel-jobs
   rm -f /mnt/args

   ARGSFILES=""
   # In Bash, the * symbol is used to expand the elements of an array as a single word,
   # with each element separated by the first character of the IFS (Internal Field Separator) variable.
   # By default, the IFS variable is set to whitespace, so the elements of the array are separated by spaces.
   # This means that the for loop iterates over the elements of the TIMES array as a single word,
   # rather than as separate words.
   # Using the @ symbol instead of * would cause the for loop to iterate over the elements of the TIMES array
   # as separate words, which is not what we want in this case.
   # For example:
   # TIMES=("00" "06" "12" "18")
   # for H in ${TIMES[*]} do echo $H done
   # 00 06 12 18
   # for H in ${TIMES[@]} do echo $H done
   # 00
   # 06
   # 12
   # 18
   for H in ${TIMES[*]}
   do
      # Write call to generate command to parallel-jobs file
      echo ./generate-tile-commands.lisp $YEAR $MONTH $DAY $HOUR $H /mnt/args$H >> /mnt/parallel-jobs
      # Append the path to the args file for the current hour to the ARGSFILE variable.
      ARGSFILE+="/mnt/args$H "
   done

   # Generate tile cutting commands
   parallel --gnu -n 1 -j $PARALLELTILE < /mnt/parallel-jobs

   # Concatenates the args files for all hours into a single args file.
   cat $ARGSFILE > /mnt/args

   echo "Done generating commands at `date`"
   
   # Generating actual tiles takes 14 minutes!
   echo "Generating grib tiles starts at `date`"

   # Execute tile cutting commands
   export OMP_NUM_THREADS=1
   parallel --gnu -n 1 -j $PARALLELTILE < /mnt/args
   export -n OMP_NUM_THREADS

   echo "Done generating grib tiles at `date`"

   rm -f /mnt/args
   rm -f /mnt/parallel-jobs
fi

# Concatenate the many different grib2 files in each windgram-tile directory into a single grib2 file
# which can then be loaded just at once by NCL. This takes 4 minutes!

if [ -z $NOTILES ]; then
    echo "Starting concatenating files for each hour at `date`"
    for H in ${TIMES[*]}
    do
        # This line generates a command that runs the required-tiles.lisp script and pipes the output
        # to the xargs command.
        # The xargs command reads the output of the required-tiles.lisp command and executes the
        # concatenate-windgram-tiles.sh script with the specified arguments for each line of output.
        # The concatenate-windgram-tiles.sh script concatenates the GRIB2 files in each windgram-tile
        # directory into a single file for the specified hour.
        # The -n 1 option specifies that xargs should execute the command once for each item of input.
        # The -d \\n option specifies the delimiter used to separate items in the input. In this case, the delimiter is a newline character (\n).
        ./required-tiles.lisp | xargs -n 1 -d \\n ./concatenate-windgram-tiles.sh $YEAR $MONTH $DAY $HOUR $H
    done
    echo "Done concatenating files for each hour at `date`"
fi

echo "Done TILE GENERATION at `date`"
