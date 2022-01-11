#!/bin/bash

if [ -z "$(type -path exiftool)" ] ;then
	echo "exiftool does not exist"
	exit 1
fi

rm -rf ../logs
mkdir ../logs

echo "*** Fix incorrectly named json files ***"

# e.g. IMG_0001.HEIC(1).json -> IMG_0001(1).HEIC.json
find . -type f -iname "*([[:digit:]]).json" | while read json ;do
	mv -v "$json" "$(echo "$json" | sed 's/\(.[[:alpha:]]*\)\(([[:digit:]])\)/\2\1/')"
done
	
echo "*** Import date and time from json file if required ***"

exiftool -progress \
	-if 'not $CreateDate' \
	-tagsfromfile %d%F.json '-createdate<photoTakenTimetimestamp' \
	-d %s -overwrite_original \
	-efile3 ../logs/import-json.log .

# Let the kludge begin

echo "*** Fix MOV files with MP4 extensions ***"

exiftool -progress \
	-if '$make =~ /^Apple/' -if '$mimetype =~ /video\/quicktime/' \
	'-filename=%d%f.MOV' \
	-ext mp4 -efile ../logs/rename-mp4.log .

echo "*** Move files from an Apple device ending with a copy number e.g. '(1)' ***"

exiftool -progress \
	-if '$filename =~ /^IMG_.*\([[:digit:]]\)/' -if '$make =~ /^Apple/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//;s/\([[:digit:]]\)//}' \
	-ext mov -ext heic -ext jpg -efile3 ../logs/move-with-copy-number.log .

echo "*** Move reminaing files from an Apple device ***"

exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//}' \
	-ext mov -ext heic -ext jpg -efile3 ../logs/move-remaining.log .

echo "*** Rename MOV files that are part of a live photo using date and time from matching image file ***"
exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' -if '$ContentIdentifier' \
	-tagsfromfile %d%f.JPG '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-tagsfromfile %d%f.HEIC '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext mov -efile3 ../logs/rename-mov.log -r ../output

echo "*** Rename all remaining files from Apple devices starting with 'IMG_' ***"

exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' \
	'-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext mov -ext heic -ext jpg -efile3 ../logs/rename-remaining.log -r ../output

echo "*** Find MP4 files that should be MOV files - redownload from photos.google.com ***"

# If you re-download these files from photos.google.com you will get MOV files 
exiftool -progress \
	-if '$make =~ /^Apple/' \
	-filepath -s3 -q -ext mp4 -r ../output | tee ../logs/broken-mp4.log

echo "*** Fix broken live photos with differing ContentIdentifier strings and incorrect extensions ***"

# There appears to be a direct correlation between live photos having differing ContentIdentifier strings
# and incorrect file type.
#
# This will check for HEIC files that have been converted to JPEG but still have a HEIC extension. Any files
# found will be renamed and the ContentIdentifier string imported from the matching MOV if it exists.
#
# Hopefully this is a working fix because none of these files will match the actual originals in any case
exiftool -if '$mimetype =~ /image\/jpeg/' -filepath -s3 -q -ext heic -r ../output | tee -a ../logs/broken-heic.list
exiftool '-filename<${filename;s/\.[^.]*$/.jpg/}' -@ ../logs/broken-heic.list
cat ../logs/broken-heic.list | sed 's/\.heic/.jpg/' > ../logs/broken-jpg.list
exiftool -progress -tagsfromfile %d%f.mov '-MediaGroupUUID<ContentIdentifier' -overwrite_original -@ ../logs/broken-jpg.list

# Everything else

echo "***Bulk move anything else with a CreateDate tag ***"

exiftool -progress \
	-if '$CreateDate' '-filename<CreateDate' \
	-d ../output/%Y/%Y-%m-%d/%Y%m%d_%H%M%S%%+c.%%le \
	-efile3 ../logs/rename-everything-else.log .