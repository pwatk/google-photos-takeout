#!/bin/bash

rm ../error.log
touch ../error.log

if [ -z "$(type -path exiftool)" ] ;then
	echo "exiftool does not exist"
	exit 1
fi

# Fix files missing CreateDate

cat <<- END
	
	Fix all json files containing an copy number in the filename
	
END

find . -type f -iname "*([[:digit:]]).json" | while read json ;do
	mv -v "$json" "$(echo "$json" | sed 's/\(.[[:alpha:]]*\)\(([[:digit:]])\)/\2\1/')"
done

cat <<- END
	
	Import CreateDate from json file if required
	
END

exiftool -progress \
	-if 'not $CreateDate' \
	-tagsfromfile %d%F.json '-createdate<photoTakenTimetimestamp' \
	-d %s -overwrite_original \
	-efile3 ../error.log -r .

# Pair and rename live photos
#
# This would be more efficient if Google hadn't dumped entire years into single directories
# and borked the ContentIdentifier strings so they no longer match for some files. 

cat <<- END
	
	Move files from Apple devices starting with 'IMG_' and ending with a copy number e.g. '(1)'
	
	Ignore minor errors regarding ExtractEmbedded option
	
END

exiftool -progress \
	-if '$filename =~ /^IMG_.*\([[:digit:]]\)/' -if '$make =~ /^Apple/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//;s/\([[:digit:]]\)//}' \
	-ext mov -ext heic -ext jpg -efile3 ../error.log -r .

cat <<- END
	
	Bulk move everything else from an Apple device starting with 'IMG_'
	
	Ignore minor errors regarding ExtractEmbedded option
	
END

exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' \
	'-filename<../output/${createdate#;DateFmt("%Y/%Y-%m-%d")}/IMG_${model;s/ /-/g}-${filename;s/IMG_//}' \
	-ext mov -ext heic -ext jpg -efile3 ../error.log -r .

cat <<- END
	
	Rename MOV files that are presumably part of live photos using CreateDate from matching HEIC or JPG in same directory
	
	Ignore minor errors regarding ExtractEmbedded option or missing files
	
END

exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' \
	-tagsfromfile %d%f.JPG '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-tagsfromfile %d%f.HEIC '-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext mov -efile3 ../error.log -r ../output

cat <<- END
	
	Rename all remaining files from Apple devices starting with 'IMG_'
	
END

exiftool -progress \
	-if '$filename =~ /^IMG_/' -if '$make =~ /^Apple/' \
	'-filename<${createdate#;DateFmt("%Y%m%d_%H%M%S_")}${filename;s/IMG_//;s/\.[^.]*$//}%+c.%le' \
	-ext mov -ext heic -ext jpg -efile3 ../error.log -r ../output

cat <<- END
	
	Fix broken live photos with differing ContentIdentifier strings and incorrect extensions
	
	Ignore minor errors regarding ExtractEmbedded option or missing files
	
END

# There appears to be a direct correlation between live photos having differing ContentIdentifier strings
# and incorrect file type.
#
# This will check for HEIC files that have been converted to JPEG but still have a HEIC extension and then
# import the ContentIdentifier string from the matching MOV if it exists.
#
# Hopefully this is a working fix because none of these files will match the actual originals in any case

exiftool -if '$filetype =~ /JPEG/' -filepath -s3 -q -ext heic -r ../output | tee -a ../broken.list
exiftool '-filename<${filename;s/\.[^.]*$/.jpg/}' -@ ../broken.list
cat ../broken.list | sed 's/\.heic/.jpg/' > ../still-broken.list
exiftool -progress -tagsfromfile %d%f.mov '-contentidentifier<ContentIdentifier' -overwrite_original -@ ../still-broken.list

# Everything else

cat <<- END
	
	Bulk move anything else with a CreateDate tag
	
END

exiftool -progress \
	-if '$CreateDate' '-filename<CreateDate' \
	-d ../output/%Y/%Y-%m-%d/%Y%m%d_%H%M%S%%+c.%%le \
	-efile3 ../error.log -r .