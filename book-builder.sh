#!/bin/bash

###################################### 
# wtf-book-builder v1.0
#
# Convert folders of mp3 files into an M4B audio with embedded metadata
#
####################################### 

####################################### 
##    DO NOT EDIT BELOW THIS LINE    ##
####################################### 

full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
log_filename="log-${short_filename}.log"

#######################################
# Formatted message logger
####################################### 
log() {
	local flag="$1"; shift
	stamp=$(date '+[%F %T]')
	case $flag in
		I) echo "$stamp - INFO: ${*}" >> "$log_filename" ;;
		IF) echo "$stamp - INFO: Found - ${*}" >> "$log_filename" ;;
		IC) echo "$stamp - INFO: Created - ${*}" >> "$log_filename" ;;
		IP) echo "$stamp - INFO: Parsed - ${*}" >> "$log_filename" ;;
		E) echo "$stamp - ERROR: ${*}" >> "$log_filename" ;;
		ENF) echo "$stamp - ERROR: Not found - ${*}" >> "$log_filename" ;;
		B) echo "$stamp - ${*}"  >> "$log_filename" ;;
	esac
}

#######################################
# Formatted message logger for stream commands
####################################### 
log-stream() {
  # used to capture stream output from command responses
  local streamLine=""
  [[ ! -t 0 ]] && while read -r streamLine; do echo "$(date '+[%F %T]') - STREAM: $streamLine" >> "$log_filename"; done
}

display-help()
{
	# Display Help
	printf "\n"
	printf "   %b\\n\\n" "WTF Book Builder"
	printf "   %b\\n\\n" "Syntax: ${CYAN}${full_filename} <path_to_folder>${NC}"
	printf "   %8s   %s\\n\\n" "<none>" "Print this Help"
}

# Output colors
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
SILVER=$(tput setaf 7)
NC=$(tput sgr0)
TICK="[${GREEN}✓${NC}]"
CROSS="[${RED}✗${NC}]"
INFO="[i]"

#######################################
# Show a formatted banner with message
####################################### 
banner () {
	local string=$1
	printf "%b \e[4m%s\e[0m\\n" "${INFO}" "${string}" && log B "*** $string ***"
}

#######################################
# Formats script terminal output
####################################### 
output () {
	local flag="$1"
	local category="$2"
	local string="$3"
	case $flag in
		T) printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${category}:" "${GREEN}${string}${NC}" ;;
		TS) printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${category}:" "${SILVER}${string}${NC}" ;;
		C) printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${category}:" "${RED}${string}${NC}" ;;
		I) printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${category}:" "${NC}${string}${NC}" ;;
		IY) printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${category}:" "${CYAN}${string}${NC}" ;;
	esac
}

#######################################
# Check for dependencies 
####################################### 
check-dependency() {
	local dependency="$1"
	if command -v "$dependency" 1> /dev/null 2> >(log-stream); then
		output T "checkDependency" "$dependency"; log IF "checkDependency: $dependency"
	else
		output C "checkDependency" "$dependency not found"; log ENF "checkDependency: $dependency"
	  exit 1
  fi
}

#######################################
# Use ffprobe to get tag data from mp3 file
####################################### 
get-mp3-tag() {
	local tag="$1"
	local file="$2"
	ffprobe -v quiet -show_entries format_tags="${tag}" -of default=noprint_wrappers=1:nokey=1 "${file}"
}

#######################################
# Process first mp3 file to get basic metadata info
####################################### 
create-metadata-from-files() {
	banner "Pulling metadata from mp3 file"
	# Pull first mp3 file out of mp3FileList
	local mdFileList=""
	read -r mdFileList < "${mp3FileList}"
 	mdFileList=$(echo "${mdFileList}" | awk -F"'" '{ print $2 }')

	# Pull tags from mp3 file
  album=$(get-mp3-tag album "${mdFileList}")
	subtitle=$(get-mp3-tag subtitle "${mdFileList}")
	artist=$(get-mp3-tag artist "${mdFileList}")
	composer=$(get-mp3-tag composer "${mdFileList}")
	genre="Audiobook"
	date=$(get-mp3-tag date "${mdFileList}")
	comment=$(get-mp3-tag comment "${mdFileList}")
	description=$(get-mp3-tag description "${mdFileList}")
	
	# Display found tags
	output IY "title" "${album}"; log I "MP3tags: title: ${album}"
	output IY "album" "${album}"; log I "MP3tags: album: ${album}"
	output IY "contentgroup" "${subtitle}"; log I "MP3tags: contentgroup: ${subtitle}"
	output IY "artist" "${artist}"; log I "MP3tags: artist: ${artist}"
	output IY "composer" "${composer}"; log I "MP3tags: composer: ${composer}"
	output IY "genre" "${genre}"; log I "MP3tags: genre: ${genre}"
	output IY "date" "${date}"; log I "MP3tags: date: ${date}"
	output IY "comment" "${comment}"; log I "MP3tags: comment: ${comment}"
	output IY "description" "${description}"; log I "MP3tags: description: ${description}"
	
	output I "MP3tags" "Writing tags to metadata file"; log I "MP3tags: Writing tags to metadata file"
	{
	  echo "title=${album}"
  	echo "album=${album}"
  	echo "contentgroup=${subtitle}"
  	echo "artist=${artist}"
  	echo "composer=${composer}"
  	echo "genre=${genre}"
  	echo "date=${date}"
  	echo "comment=${comment}"
  	echo "description=${description}"
	} >>"${metaFile}" && output T "MP3tags" "${metaFile} updated"; log I "MP3tags: ${metaFile} updated"
}

#######################################
# Process mp3 files to generate chapters based on duration
####################################### 
create-chapters-from-files() {
	local previous_seconds=0
	local chapterLine=""
	banner "Generating chapters from mp3 files"
  while read -r chapterLine; do
  	filename=$(basename "$chapterLine")
  	chapterLine=$(echo "$chapterLine" | awk -F"'" '{ print $2 }')
		output IY "createChapters" "Generating chapter info: ${filename}"; log I "createChapters: Generating chapter info: ${filename}"
    fileDuration=$(ffprobe -v quiet -show_entries format="duration" -of default=noprint_wrappers=1:nokey=1 "$chapterLine")
  	{
  		echo "[CHAPTER]"
  		echo "TIMEBASE=1/1"
  		echo "START=${previous_seconds}"
  		end_time=$(echo "$previous_seconds + $fileDuration" | bc -l)
  		echo "END=${end_time}"
  		echo "title=$(get-mp3-tag title "$chapterLine")"
    	previous_seconds=$end_time
  	} >>"${metaFile}"
  done <"${mp3FileList}" && output T "createChapters" "${metaFile} updated"; log I "createChapters: ${metaFile} updated"
}

#######################################
# Create metadata for m4b file
####################################### 
create-metadata() {	
	# Look for ABS metadata file first and if not found, work on the files directly
	local metaLine=""
	echo ";FFMETADATA1">"${metaFile}"
	if [ -f "${folderPath}"/metadata.json ]; then
		banner "Parsing metadata from ABS json file"
		output T "parseABSmetadata" "metadata.json"; log IF "parseABSmetadata: ${bookName}/metadata.json"

		# Pull tags from mp3 file
	  album=$(cat "${folderPath}"/metadata.json | jq -r '.title')
		subtitle=$(cat "${folderPath}"/metadata.json | jq -r '.subtitle')
		artist=$(cat "${folderPath}"/metadata.json | jq -r '.authors[]')
		composer=$(cat "${folderPath}"/metadata.json | jq -r '.narrators[]')
		genre="Audiobook"
		date=$(cat "${folderPath}"/metadata.json | jq -r '.publishedYear')
		description=$(cat "${folderPath}"/metadata.json | jq -r '.description')

		echo ";FFMETADATA1" >"$metaFile"
		echo "title=$(cat "${folderPath}"/metadata.json | jq -r '.title')" >>"$metaFile"
		echo "album=${album}" >>"$metaFile"
		echo "contentgroup=${subtitle}" >>"$metaFile"
		echo "artist=${artist}" >>"$metaFile"
		echo "composer=${composer}" >>"$metaFile"
		echo "genre=Audiobook" >>"$metaFile"
		echo "date=${date}" >>"$metaFile"
		echo "comment=${description}" >>"$metaFile"
		echo "description=${description}" >>"$metaFile"
		cat "${folderPath}"/metadata.json | jq -r '.chapters[] | "\(.start),\(.end),\(.title)"' | while read -r metaLine; do
			{
			echo "[CHAPTER]"
			echo "TIMEBASE=1/1"
			echo "START=$(echo "$metaLine" | awk -F"," '{print $1}')"
			echo "END=$(echo "$metaLine" | awk -F"," '{print $2}')"
			echo "title=$(echo "$metaLine" | awk -F"," '{print $3}')"
			} >>"$metaFile"
		done
	else
		output C "parseABSmetadata" "metadata.json not found"; log ENF "parseABSmetadata: ${bookName}/metadata.json"
		output I "parseABSmetadata" "Will try to build from mp3 files"; log I "parseABSmetadata: Will try to build from mp3 files"
		create-metadata-from-files
		create-chapters-from-files
	fi
}

#######################################
# Look for cover.jpg or folder.jpg in the book folder
####################################### 
check-for-cover () {
	coverFileName=""
	if [ -f "${folderPath}"/cover.jpg ] ; then
		coverFileName="${folderPath}/cover.jpg"
		output T "Cover" "cover.jpg"; log IF "Cover File: ${coverFileName}"
	elif [ -f "${folderPath}"/folder.jpg ] ; then
		coverFileName="${folderPath}/folder.jpg"
		output T "Cover" "folder.jpg"; log IF "Cover File: ${coverFileName}"
	else
		output C "Cover" "Cover file not found."; log ENF "Cover File: ${coverFileName}"
	fi
}

#######################################
# Build list of mp3 files for book folder
####################################### 
build-file-list () {
	output I "mp3FileList" "${mp3FileList}"; log I "mp3FileList: ${mp3FileList}"
	if [ -d "${folderPath}" ] ; then
		find "${folderPath}" -type f -name "*.mp3" -exec printf "file '%s'\n" {} \; | sort >"$mp3FileList" &&	output T "mp3FileList" "${mp3FileList}"; log IC "mp3FileList: ${mp3FileList}"	
	else
		output C "mp3FileList" "${mp3FileList}"; log E "mp3FileList: ${mp3FileList}"
		exit 1
	fi
}

#######################################
# Use ffmpeg to concatenate sorted mp3 files
####################################### 
combine-mp3-files () {
	local line_count
	local singleFile
	output I "mp3Combine" "Source - ${mp3FileList}"; log I "mp3Combine: Source - ${mp3FileList}"
	output I "mp3Combine" "Target - ${mp3Combine}"; log I "mp3Combine: Target - ${mp3Combine}"
	line_count=$(wc -l < "${mp3FileList}")
	if [ "$line_count" -gt 1 ]; then
		ffmpeg -hide_banner -y -v quiet -stats -f concat -safe 0 -i "${mp3FileList}" -c copy "${mp3Combine}" &
		combinePID=$!
		wait $combinePID
		if [ "$?" -eq 0 ] ; then
			output T "mp3Combine" "${mp3Combine}"; log IC "mp3Combine: ${mp3Combine}"
	    combineDuration=$(ffprobe -v quiet -show_entries format="duration" -of default=noprint_wrappers=1:nokey=1 -sexagesimal "${mp3Combine}")
			output T "mp3Combine" "Duration - ${combineDuration}"; log IC "mp3Combine: Duration - ${combineDuration}"
		else
			output C "mp3Combine" "${mp3Combine}"; log E "mp3Combine: ${mp3Combine}"
			cat "$log_filename"
			exit 1
		fi
	else
		output I "mp3Combine" "Single file - Cannot combine."; log I "mp3Combine: Single file - Cannot combine."
		read -r singleFile < "${mp3FileList}"
		mp3Combine=$(echo "${singleFile}" | awk -F"'" '{ print $2 }')
		output T "mp3Combine" "${mp3Combine}"; log IC "mp3Combine: ${mp3Combine}"
    combineDuration=$(ffprobe -v quiet -show_entries format="duration" -of default=noprint_wrappers=1:nokey=1 -sexagesimal "${mp3Combine}")
		output T "mp3Combine" "Duration - ${combineDuration}"; log IC "mp3Combine: Duration - ${combineDuration}"
	fi
}

#######################################
# Convert concatenated mp3 file to m4a
####################################### 
convert-mp4-file () {
	output I "mp4Convert" "Source - ${mp3Combine}"; log I "mp4Convert: Source - ${mp3Combine}"
	output I "mp4Convert" "Target - ${m4bConvertFileName}"; log I "mp4Convert: Target - ${m4bConvertFileName}"
	if [ -f "${mp3Combine}" ] ; then
		#ffmpeg -y -v quiet -stats -i "${mp3Combine}" -c:v copy "${m4bConvertFileName}"
		ffmpeg -hide_banner -y -v quiet -stats -i "${mp3Combine}" -c:v copy "${m4bConvertFileName}" &
		convertPID=$!
		wait $convertPID
		if [ "$?" -eq 0 ] ; then
			output T "mp4Convert" "${m4bConvertFileName}"; log IC "mp4Convert: ${m4bConvertFileName}"
		else
			output C "mp4Convert" "${m4bConvertFileName}"; log E "mp4Convert: ${m4bConvertFileName}"
			exit 1
		fi
	else
		output C "mp4Convert" "${m4bConvertFileName}"; log E "mp4Convert: ${m4bConvertFileName}"
	 	exit 1
	fi
}

#######################################
# Embed metadata in m4b file
####################################### 
add-metadata () {
	if [ -n "${album}" ] && [ -n "${artist}" ]; then
		m4bFileName="${artist} - ${album}.m4b"
		m4bFileName="${m4bFileName//[\"\'\`\/]/}"
	else
		m4bFileName="${bookName}.m4b"
		m4bFileName="${m4bFileName//[\"\'\`\/]/}"
	fi
	output I "addMetadata" "metadata -> ${m4bFileName}"; log I "addMetadata: metadata -> ${m4bFileName}"
	if [ -n "${coverFileName}" ]; then
		ffmpeg -y -v quiet -stats -i "${m4bConvertFileName}" -i "${metaFile}" -i "${coverFileName}" -map 0:a -map_metadata 1 -map 2:v -disposition:v:0 attached_pic -c copy -movflags +faststart "${m4bFileName}" &
		addMetadataPID=$!
		wait $addMetadataPID
		if [ "$?" -eq 0 ] ; then
			output T "addMetadata" "${m4bFileName}"; log IC "addMetadata: ${m4bFileName}"
		else
			output C "addMetadata" "${m4bFileName}"; log E "addMetadata: ${m4bFileName}"
			exit 1
		fi
	else
		ffmpeg -y -v quiet -stats -i "${m4bConvertFileName}" -i "${metaFile}" -map 0 -map_metadata 1 -c copy "${m4bFileName}" &
		addMetadataPID=$!
		wait $addMetadataPID
		if [ "$?" -eq 0 ] ; then
			output T "addMetadata" "${m4bFileName}"; log IC "addMetadata: ${m4bFileName}"
		else
			output C "addMetadata" "${m4bFileName}"; log E "addMetadata: ${m4bFileName}"
			exit 1
		fi
	fi
}

#######################################
# Copy completed m4b file to book folder
####################################### 
copy-m4b () {
	if [ -f "${m4bFileName}" ]; then
		output I "copyM4B" "Source - ${m4bFileName}"; log I "copyM4B: Source - {m4bFileName}"
		output I "copyM4B" "Target - ${folderPath}"; log I "copyM4B: Target - ${folderPath}"
		if cp "${m4bFileName}" "${folderPath}"/ 1> /dev/null 2> >(log-stream); then
			output T "copyM4B" "${m4bFileName}"; log I "Copied: ${folderPath}/${m4bFileName}"
		else
			output C "copyM4B" "${m4bFileName}"; log E "Copy failed: ${folderPath}/${m4bFileName}"
			exit 1
		fi
	else
		output C "copyM4B" "${m4bFileName}"; log E "copyM4B: ${m4bFileName} not found"
		exit 1
	fi
}

#######################################
# Cleanup all files used 
####################################### 
clean-up () {
  local cleanupFile="${1}"
	if rm "${cleanupFile}" 1> /dev/null 2> >(log-stream) ; then
		output T "Cleanup" "${cleanupFile}"; log I "Cleanup: ${cleanupFile}"
	else
		output C "Cleanup" "${cleanupFile}"; log ENF "Cleanup: ${cleanupFile}"
	fi
}

#######################################
# Process book directory passed by process-dirs
####################################### 
process-books () {
	folderPath="${1}"
	bookName=$(basename "${folderPath}")
	bookName="${bookName//[\"\'\`]/}"
	
	# Output files
	mp3FileList="${bookName}.files.txt"
	metaFile="${bookName}.meta"
	mp3Combine="${bookName}.combine.mp3"
	m4bConvertFileName="${bookName}.converted.m4a"
	m4bFileName=""
	
	banner "Starting conversion for:${CYAN} ${folderPath}${NC}"
	
	banner "Building File List.."
	build-file-list "${folderPath}"
	
	banner "Checking for Cover file.."
	check-for-cover
	
	banner "Generating metadata for ffmpeg.."
	create-metadata
	
	banner "Combining MP3 files.."
	combine-mp3-files
	
	banner "Converting to MP4.."
	convert-mp4-file
	
	banner "Adding metadata to file.."
	add-metadata
	
	banner "Copying M4B.."
	copy-m4b
	
	banner "Cleaning up book temp files.."
	clean-up "${mp3FileList}"
	clean-up "${metaFile}"
	clean-up "${mp3Combine}"
	clean-up "${m4bConvertFileName}"
	clean-up "${m4bFileName}"
}

#######################################
# Process base directory passed to script
####################################### 
process-dirs () {
	inputPath="${1}"
	#clear
	rm "$log_filename" 1> /dev/null 2> >(log-stream)
	banner "Checking for dependencies"
	check-dependency ffmpeg
	check-dependency jq
	
	banner "Processing Input Path: ${inputPath}"

	find "${inputPath}" -type d -exec bash -c '
	  for dir; do
	    if ls "${dir}"/*.mp3 1> /dev/null 2>&1 && ! ls "${dir}"/*.m4b 1> /dev/null 2>&1; then
	      echo "${dir}"
	    fi
	  done
	' bash {} + > cleanDirs.txt

	cleanDirCount=$(wc -l < cleanDirs.txt)

	if [ "$cleanDirCount" -gt 0 ]; then
		banner "Book directories to be processed: ${cleanDirCount}"
		cat cleanDirs.txt | while IFS= read -r line; do	
			banner "Processing directory: ${line}"
			process-books "${line}"
		done
		banner "Cleaning up final temp files.."
		clean-up cleanDirs.txt
		banner "All book directories processed"
	else
		output T "processDirs" "No directories to be processed"; log I "processDirs: No directories to be processed"
		banner "Cleaning up book temp files.."
		clean-up cleanDirs.txt
	fi
}

#######################################
## Main script
#######################################

if [ -d "${1}" ]; then
		process-dirs "${1}"
else
		echo "Invalid path specified."
		display-help
fi
