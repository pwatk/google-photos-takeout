#!/bin/bash

photos="$1"
logs=../logs
output=../output

if [ -z "$(type -path exiftool)" ] ;then
	echo "exiftool does not exist"
	exit 1
fi

if [ -z "$photos" ] || [ ! -d "$photos" ] ;then
	echo "$(basename "$0") /path/to/photos"
	exit 1
fi

cd "$photos" || exit 1

mkdir -p "$logs" || exit 1

echo "
Fix incorrectly named json files (e.g. IMG_0001.HEIC(1).json -> IMG_0001(1).HEIC.json)
" | tee "$logs"/json.txt

find . -type f -iname "*([[:digit:]]).json" | while read json ;do
	mv -v "$json" "$(echo "$json" | sed 's/\(.[[:alpha:]]*\)\(([[:digit:]])\)/\2\1/')"
done \
	2>&1 | tee -a "$logs"/json.txt
	
echo "
Import Create Date tag from json files if required
" | tee -a "$logs"/json.txt

exiftool \
	-if 'not $CreateDate' \
	-tagsfromfile %d%F.json \
	'-createdate<photoTakenTimetimestamp' \
	-d %s \
	-overwrite_original \
	-efile3 "$logs"/json-err.txt \
	-progress \
	. \
	2>&1 | tee -a "$logs"/json.txt

echo "
Fix file extensions
" | tee "$logs"/extensions.txt

exiftool \
	-if '$mimetype =~ /video\/quicktime/' \
	'-filename=%d%f%+c.MOV' \
	-ext mp4 \
	-execute \
	-if '$mimetype =~ /image\/jpeg/' \
	'-filename=%d%f%+c.JPG' \
	-ext heic \
	-common_args \
	-if '$make =~ /^Apple/' \
	-efile3 "$logs"/extensions-err.txt \
	-progress \
	. \
	2>&1 | tee -a "$logs"/extensions.txt

echo "
Apple Live Photos
" | tee "$logs"/live-photos.txt

exiftool \
	'-filename<$ContentIdentifier.%le' \
	-ext mov \
	-ext mp4 \
	-execute \
	'-filename<$MediaGroupUUID.%le' \
	-ext heic \
	-ext jpg \
	-execute \
	-tagsfromfile %d%f.jpg \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}_${MediaGroupUUID;s/-.*$//}.%le' \
	-tagsfromfile %d%f.heic \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}_${MediaGroupUUID;s/-.*$//}.%le' \
	-ext mov \
	-ext mp4 \
	-execute \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}_${ContentIdentifier;s/-.*$//}.%le' \
	-ext mov \
	-ext mp4 \
	-execute \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}_${MediaGroupUUID;s/-.*$//}.%le' \
	-ext heic \
	-ext jpg \
	-common_args \
	-if '$make =~ /^Apple/' \
	-if '$ContentIdentifier or $MediaGroupUUID' \
	-efile3 "$logs"/live-photos-err.txt \
	-progress \
	. \
	2>&1 | tee -a "$logs"/live-photos.txt

echo "
Apple Burst Photos
" | tee "$logs"/burst-photos.txt

exiftool \
	-if '$make =~ /^Apple/' \
	-if '$BurstUUID' \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}-${SubSecTimeOriginal}_${BurstUUID;s/-.*$//}.%le' \
	-efile3 "$logs"/burst-photos-err.txt \
	-progress \
	. \
	2>&1 | tee -a "$logs"/burst-photos.txt
	

echo "
Rename everything else with a Create Date tag
" | tee "$logs"/everything-else.txt

exiftool \
	-if '$CreateDate' \
	"-filename<$output"'/${CreateDate;DateFmt("%Y/%Y-%m-%d/%Y%m%d_%H%M%S")}%+3c.%le' \
	-efile3 "$logs"/everything-else-err.txt \
	-progress \
	. \
	2>&1 | tee -a "$logs"/everything-else.txt