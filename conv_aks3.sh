#!/bin/bash

####################################################################
## Convert script
##
## Usage:
##   conv_aks source.aks dest_stub
##
## Example:
##   conv_aks knightmare.aks tunes\knightmare
##   # outputs:
##   #   knightmare.aky.s
##   #   knightmare.events.words.s
##   #   knightmare.samples.s
##   #   knightmare.raw.linear.s

usage()
{
    echo usage: conv_aks source.aks dest_stub
    exit 1
}

if [ "$1" == "" ]; then usage; fi
if [ "$2" == "" ]; then usage; fi

set -e

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    extension="mac";SED=gsed;;
    *)          extension="linux";SED=sed;;
esac

bin3/SongToAky_${extension} --subsong 1 -adr 0 --customSourceProfileFile bin3/rmac.xml "$1" "$2.aky.s"
bin3/SongToEvents_${extension} -adr 0 --customSourceProfileFile bin3/rmac.xml "$1" "$2.events.words.s"
bin3/SongToSamples${extension} --customSourceProfileFile bin3/rmac.xml --sampleExportOffset 0 --sampleExportAmplitude 16 %1 %2.samples.s
bin3/SongToRawLinear${extension} --customSourceProfileFile bin3/rmac.xml %1 %2.raw.linear.s --labelPrefix "arkos_samples"

# Currently (v3.2.4) Arkos the cli tools seem to be using DOS line endings.
# So let's just use dos2unix for now
#dos2unix "$2.aky.s"
#dos2unix "$2.events.words.s"
# On second thoughts, let's use sed for this, reduce dependencies and all
$SED -i -e $'s/\r$//' "$2.aky.s"
$SED -i -e $'s/\r$//' "$2.events.words.s"

# Since Arkos Tracker 3 removed the functionality to use relative offsets
# (i.e. Subsong_0_XXX-Subsong0) we'll just do it by hand here. No problem
# (incidentally, this is the only thing that was stopping Arkos Tracker 3 tunes from
# working - if we exclude the new xml source profiles)
# (This is a setting while exporting via the GUI though!)
$SED -i -e "/dc.w Subsong/s/$/& - Subsong0/" "$2.aky.s"

# Convert event values to word size and labels to longwords
$SED -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" "$2.events.words.s"

# Strip out all effects from raw linear
$SED -i -e "/Effect/d" %2.raw.linear.s
$SED -i -e "/effects/d" %2.raw.linear.s
# fix bug as of Arkos 3.5 tools: an empty label prefix creates a label called ":"
$SED -i -e "s/^:$//" %2.raw.linear.s

# Same as above, but for samples. Might not be used eventually (we can convert the dc.ws to dc.ls
# and be rid of all the relative pointer nonsense)
$SED -i -e "s/\(dc.w Sample_Sample..\)/\1 - SampleDisarkPointerRegionStart0/" %2.samples.s
# all $ characters should be converted to *
$SED -i -e "s/\$//" %2.samples.s

echo

