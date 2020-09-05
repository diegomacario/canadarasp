# canadarasp
All the stuff that runs www.canadarasp.com a website that tries to provide two things:

* Easy to understand summaries in the form of windgrams which provide a soaring forecast for paraglider, hang glider, and sail plane pilots in Canada and the northern United States.
* Complete data to allow a deep or shallow dive into the forecast in the form of a map view.

We also serve a large population of kite boarders, though I do not
know whether they mainly use the map view for surface winds or the
windgrams.

We also have as customers a few coastal engineering firms that are
interested in wind forecasts with regards to interaction with wave and
water damage.  This is the origin of the BC archive map which is used
by a small firm in BC (they paid a small amount of money for me to add
that feature) where they like to be able to look and see the forecasts
on days where there was storm damage at lake waterfronts.  The surface
wind archiving system was commissioned by a larger engineering firm
and it also hangs out on the web server machine (but takes very little
processing --- it just archives some data from the forecasts to S3 and
processes it on demand when requested through a simple web service).

# System generalities

This runs in the Amazon cloud in ca-central-1a, which is Montreal.
This is mainly because data transfers from ECCC appear fastest from
there.  The system consists of a t3.small EC2 instance which I will
refer to as the web server and intermittently a c5d.4xlarge EC2
instance called the compute server.

The compute stack is hideous, a mix of bash scripts, common lisp for
data processing, wgrib2 and gdalwarp for data processing, and NCL for
drawing the windgrams.  Historically NCL used to be used for almost
all of the data handling when we were just visualizing the area around
BC off the HRDPS-WEST model, but once we moved to the continental
model it was about 10x too slow to be useful, so I wrote the stuff
that needed to be fast in common lisp.

It costs roughly $1300 CAD / year to run the system.

# ECCC

We rely on the freely available data from Environment and Climate
Change Canada.  The HRDPS model runs four times per day at 00Z, 06Z,
12Z, 18Z.  We focus on serving west coast pilots who want a morning
forecast before they head out and an evening forecast before bedtime.
This well served by the 06Z and 18Z cycles which are ready at roughly
12:30Z and 01:15Z or 4:30AM and 5:15PM pacific time (depending on DST,
etc).  Can probably tweak the timing a bit here to get the data a bit
earlier.  We only run the 06 and 18Z data cycles.  To better serve the
east coast we might add one but it would cost several hundred dollars
a year more and I don't know the uptake in the east yet.  Not so much
terrain on the Canadian side of the border so they are probably well
served by the general weather and aviation forecasts.

## Data

The data comes in the form of GRIB2 files.  These are compressed files
each of which contains an individual forecast field across the
forecast area: like temperature at a given pressure, or wind
components, etc.  Compressed an HRDPS run for the fields we use is
about 10 GB of data.  Some of the processing time comes from
uncompressing these files at compute time to get the data we want.
There are many libraries and command line tools to handle these sort of files.

For some basic data handling and for cutting out the dynamic windgram tiles, we use
[WGRIB2](https://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/)

For handling the map pngs we use [GDALWARP](https://gdal.org/programs/gdalwarp.html) and the GDAL
library from the Common Lisp code.

### Data details

To efficiently generate windgrams, we cannot load the entire data set
into memory (actually NCL just refuses to and dies --- it is 10GB
compressed, > 400GB uncompressed).  So we slice up the data
into 2x2 degree squares for each field and then we concatenate all the
fields into a 2x2 degree windgram tile.  While generating the map pngs
we work on each field individually, so we can load them directly
though we still output 2x2 degree PNGs for speed of loading in the web
browser.

## WCS / WMS

ECCC provides a WCS and WMS interface to the HRDPS data.  My
experiments with trying to use the WCS interface found it was about
100x too slow to be useful for generating dynamic windgrams.  I did
not investigate the WMS interface to replace the map pngs, but I
expect it to be as slow.

## Contacts

The ECCC team is very responsive.  Their point contact person for
their data products is Sandrine at dd_info@ec.gc.ca who is always very
helpful.  The WCS/WMS stuff is the Geomet team who I have not
interacted with yet (as my experiments with those interfaces were
disappointing).

# web server
## General
A t3.small EC2 instance runs the multiple web-server components
(Apache2 static serving and proxying to internal services, dynamic wind grams, a time zone service, and
an unrelated surface winds query service found in git repo
hrdps-coastal-info).  There are no automated builds of this system,
you'll have to do it by hand.  I regularly keep a couple snapshots of
this to allow easy rebuilds if something goes completely haywire.

Multiple times per day (see canadarasp/crontab) the web-server
instance downloads data for the HRDPS or GDPS from ECCC.  This is the
part of the system that most likely fails due to ECCC failing to have
data or having issues delivering data on time.  This is handled by
`canadarasp/aws-utils/download-data-and-start-server.sh MODEL` where
MODEL is either gdps or hrdps depending.

## Software
### download-data-and-start-server.sh MODEL
**SUMMARY: This is the start of the data processing pipeline.  Download data and start the compute server**

MODEL is either hrdps or gdps.

As seen in canadarasp/crontab, this is invoked at 01:15Z and 12:30Z
for HRDPS and 08:15Z for GDPS.  These times are chosen so that the
ECCC models are finished by then.  One could trigger this off of their
AMQP message service, but I wasted a few hours fiddling with this and
I couldn't figure out how to tell when the data was complete.

The general scheme of this is:
 * Create / mount a new EC2 volume called download-box-MODEL
 ** This fails semi regularly, maybe once every few month due to what look like AWS failures.  I have not managed to pin it down or make a reliable workaround.  If this happens, reboot the web-server (it is un-recoverable without a reboot --- force unmounting makes it fail again later) and delete the old volume and manually retrigger the run that died if you want.
 * Download data to the download-box.  This script is reasonably robust and will wait for up to 3 hours for data to be available.
 * Unmount / detach the download-box
 * Start the EC2 compute-server with the name HRDPS PROD V7 (see default at top of this script).  This machine is very expensive to run, which is why we do the downloading on the web-server.  When ECCC is flaky sometimes the download can take a significant amount of time (usually it's done in less than 10 minutes for the 10GB of data or so for the HRDPS).  We also set a tag on the compute server telling it which model we are giving it data for (just so it knows which download-box / ec2 volume to mount).  There is another tag on the compute server called shutdown.  If it is true the machine shuts down when finished.  If false, it doesn't.  This is just convenient for debugging the system.  Don't forget to set it back to true when done fiddling.
 * Wait three hours and kill the compute server just in case something goes wonky.  Avoids unnecessary costs when things go wrong.

we download 48 hours for the HRDPS (it outputs data every hour) and 99
hours for the GDPS (it outputs data every 3 hours).

# compute-server

## General

The compute server is a c5d.4xlarge machine that is spun up three
times a day to process the HRDPS and GDPS data.  It runs for about 1
hour for each HRDPS run and significantly less for the GDPS data.
This is the main cost of the system.  I use a c5d.4xlarge so the
morning runs can be finished by the time people wake up in the morning
on the west coast.  To better serve the east coast I would have to add
an HRDPS run (say the 12Z run) which would cost several hundred
dollars a year more.  This is a *d.* machine because I use the onboard
400GB SSD for storing intermediate results in the data processing
pipeline.  The performance of an EC2 volume with enough IOPS might be
good enough but would cost more in the end.

The compute server when started starts up
`continental-test/do-rasp-run-continental.sh` through /etc/rc.local

The naming here (continental-test) is just historical and I've been
too lazy to change it.  continental-test has nothing to do with tests
or with testing, it just refers to me branching off the code to handle
the huge volume of the continental HRDPS data set.

## Software components

We use a mix of bash and common lisp as a scripting language (it turns
out that bash is too slow for some of the steps, taking minutes to
perform operations that take seconds when written in common lisp ---
remember this machine is expensive!  I only switched to common lisp
for the scripting components after I exhausted trying to speed up bash
to be useful).  Generally all these scripts can handle different model
data sets, the differences being encoded in model-parameters.sh /
model-parameters.lisp and the equivalent in the windgram ncl scripts.

### do-rasp-run-continental.sh

**Summary: copy data to local disk and setup processing environment **

This script is run on boot by /etc/rc.local on the compute-server.

This script initializes the internal SSD and creates a local swap file
(needed for stability later, though we don't actually swap in steady
state).

This script attaches and mounts the download box, copies the data to
the local SSD, detaches and deletes the download box.

Then it calls `continental-test/do-hrdps-plots-continental.sh`

### do-hrdps-plots-continental.sh $YEAR $MONTH $DAY $HOUR

**Summary: generate windgrams, map tiles, and dynamic windgram data tiles and upload them all to the web-server **

YEAR MONTH DAY HOUR are the forecast initialization time.  These are
just handled by `guess-time.sh MODEL`.  This works fine, though the
design is relatively fragile.  We could frob this from the filenames
on the download box.  But this works OK for now.

There are six main steps here:
 1. `do-generate-new-variables.sh` which computes some new parameters (HCRIT, WSTAR) across the whole domain and are used in the map soaring forecasts.  These are re-computed in the windgram scripts because I was too lazy to fix them.
 2. `clip-wind-to-terrain.sh` which clips the wind fields to terrain (this seems to be broken --- this has to do with which file has the terrain information).  This makes a nicer looking map, but isn't truly necessary.
 3. `do-tile-generation.sh` which generates the grib2 files used by the windgram generation scripts (both static and dynamic generation).
 4. `do-windgrams-continental.sh` which generates the static windgrams for all the sites in locations.txt and uploads them back to the web server (along with a locations / regions list to be read by the javascript front end).  It also uploads the grib2 tile files generated in step 3 back to the web server for the dynamic windgram generation.
 5. `generate-single-hrdps-plot-continental.lisp` which generates the PNG and pseudo-PNG files for the google maps interface.
 6. `upload-map-pngs.sh` uploads the PNG files back to the web server.

Generally for each of these we grab the model-parameters which are
encoded in model-parameters.sh and model-parameters.lisp to tell us
something about the files we are processing.

### windgram generation

The NCL code that draws this is based on some ancient code by TJ
Olney, a paraglider pilot from Washington state.  His code is a lot
like his car and his house were, just piles of stuff organized in a
scheme only he could understand.  Despite that, he created a
visualization that is amazingly intuitive for most pilots.  He died
paragliding right after retiring from his day job.  That code also
used to use some fortran code from Dr. Jack Glendening, the creator of
"RASP" which was a set of scripts that ran an ancient version of WRF
based on NAM input data.  I excised the fortran code as Dr. Jack made
it expire at some point in time.  It was unnecessary.  The windgram
code was heavily hacked by Peter Spear and myself to handle the
different data from ECCC.

# front end
## General

The front end is a mixture of javascript, CSS, and html.  The map
viewer was originally based on code from Paul Scorer, a sail plane
pilot from the UK. Most of the bits are gone from that, but some of it
still exists.  It works, but it isn't particularly pretty.

Generally we are only displaying static PNGs and the like for the map
viewer, but we encode wind direction in a pseudo-png and draw the
arrows in the client.  This saved several hundred dollars a year in
compute costs server side.

# Plans

## Store higher resolution data and move drawing to the client

I would like to change the map viewer so the user can specify the
color scales interactively.  To do so I would change the static PNGs
to all be pseudo-PNGs where I encode the raw data.  You can think of
this as me doing bespoke compression on the original data.  Right now
when I write the PNGs out they are significantly smaller (10x) that
the original data set.  That's because the original data set uses
double floats to encode the data (64-bits per point) while we are
using something like 4 bits per point (we actually don't used paletted
PNGs which would save even more space, but the compression takes care
of the repeated colors nicely).  Both are compressed with similar
algorithms.  The size reduction is noticeable --- it's 4.6GB in PNG
format.  Going back to say 8 bits per point, eg quantizing wind speeds
to 1 km/hr would still be manageable.  We could also switch to just
slicing the entire data set up and leaving it in GRIB2 format and
serving that raw and using any of the geo javascript libraries to
decode it.  That's probably the simplest.  Either way, GRIB2 or
pseudo-PNG we could then move the windgram generation to the client
side if serving those static files is fast enough.  Or, I could write
a thin web service that mimics WCS over these pre-sliced files.  The
funny thing is this is what WCS is supposed to be --- provide a nice
interface to getting raw data, but to make it performant is tricky I
guess.  It really looks like they don't decompress the data in
advance, or slice it up like I do, so it ends up taking half a second
to just query a single field at a single point.

## Improved interface and visualization

I don't really want to compete with things like windy, etc, as they do
their jobs well, but we could make this look a lot nicer especially if
we provide a WCS like interface to the data.

## Remove NCL for windgram generation

NCL is a deprecated scripting language (seems they have a python based
replacement for it?).  We could move to that, or we could do the above
two tasks and rewrite the drawing code in javascript.

## Support for GFS and NAM

I'd like to support the NAM and GFS models.  The GFS model would cost
little to add aside from having to go through and see how the data is
packed, etc.  The NAM model, though, would again cost several hundred
dollars a year to process and I'm not sure I'd get enough increase in
users to cover the cost.  Mainly the development time is what's
stopping me though.  I just don't have the motivation right now.