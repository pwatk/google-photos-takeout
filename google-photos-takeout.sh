#!/bin/bash

if [ -z "$(type -path exiftool)" ] ;then
	echo "exiftool does not exist"
	exit 1
fi

photos="$1"

if [ -z "$photos" ] || [ ! -d "$photos" ] ;then
	echo "$(basename "$0") /path/to/photos"
	exit 1
fi

cd "$photos" || exit 1

mkdir -p ../logs || exit 1
rm ../logs/*.txt

echo "
1) Fix incorrectly named json files
" | tee ../logs/01-fix-json.txt

# e.g. IMG_0001.HEIC(1).json -> IMG_0001(1).HEIC.json
find . -type f -iname "*([[:digit:]]).json" | while read json ;do
	mv -v "$json" "$(echo "$json" | sed 's/\(.[[:alpha:]]*\)\(([[:digit:]])\)/\2\1/')"
done \
	2>&1 | tee -a ../logs/01-fix-json.txt
	
echo "
2) Import Create Date tag from json files if required
" | tee ../logs/02-import-json.txt

exiftool -progress \
	-if 'not $CreateDate' \
	-tagsfromfile %d%F.json '-createdate<photoTakenTimetimestamp' \
	-d %s -overwrite_original \
	. \
	2>&1 | tee -a ../logs/02-import-json.txt

# Let the kludge begin

echo "
3) Fix MOV files with MP4 extensions
" | tee ../logs/03-fix-mov-extensions.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$mimetype =~ /video\/quicktime/' \
	'-filename=%d%f.MOV' \
	-ext mp4 \
	. \
	2>&1 | tee -a ../logs/03-fix-mov-extensions.txt
	
echo "
4) Fix JPG files with HEIC extensions
" | tee ../logs/04-fix-jpg-extensions.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$mimetype =~ /image\/jpeg/' \
	'-filename=%d%f.JPG' \
	-ext heic \
	. \
	2>&1 | tee -a ../logs/04-fix-jpg-extensions.txt

echo "
5) Move all files from an Apple device that include a copy number e.g. IMG_0001(1).HEIC
" | tee ../logs/05-move-1.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$filename =~ /^IMG_.*\([[:digit:]]\)/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//;s/\([[:digit:]]\)//}' \
	-ext heic \
	-ext jpg \
	-ext mov \
	-ext mp4 \
	. \
	2>&1 | tee -a ../logs/05-move-1.txt

echo "
5) Move reminaing files from an Apple device
" | tee ../logs/05-move-2.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$filename =~ /^IMG_/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//}' \
	-ext heic \
	-ext jpg \
	-ext mov \
	-ext mp4 \
	. \
	2>&1 | tee -a ../logs/05-move-2.txt

echo "
6) Rename video files with a Content Identifier tag using the Create Date tag from the matching photo (if it exists).
" | tee ../logs/06-rename-live-video.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$filename =~ /^IMG_/' \
	-if '$ContentIdentifier' \
	-tagsfromfile %d%f.JPG '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-tagsfromfile %d%f.HEIC '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext mov \
	-ext mp4 \
	-r ../output \
	2>&1 | tee -a ../logs/06-rename-live-video.txt

echo "
7) Rename all remaining files from an Apple device
" | tee ../logs/07-rename-remaining-apple.txt

exiftool -progress \
	-if '$make =~ /^Apple/' \
	-if '$filename =~ /^IMG_/' \
	'-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext heic \
	-ext jpg \
	-ext mov \
	-ext mp4 \
	-r ../output \
	2>&1 | tee -a ../logs/07-rename-remaining-apple.txt

# Everything else

echo "
8) Bulk move everything else with a Create Date tag
" | tee ../logs/08-everything-else.txt

exiftool -progress \
	-if '$CreateDate' \
	'-filename<CreateDate' \
	-d ../output/%Y/%Y-%m-%d/%Y%m%d_%H%M%S%%+c.%%le \
	. \
	2>&1 | tee -a ../logs/08-everything-else.txt