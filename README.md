> [!WARNING]
> The script will fail if the file or directory name contains characters that ffpmeg does not like.
> 
> IE - ', ", `, Tab, &, #, * \, /, !
>
> I'm working on a function to report on these and possibly replace the offending characters.

# Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Future Plans](#future-plans)

# Overview
A script to convert directories of mp3 files to a single m4b per directory and add metadata.

Features:
- Parse .json file from [audiobookshelf](https://www.audiobookshelf.org) if it exsits in the directory.
- If the ABS json file is not found
  - Pull tag data from the mp3 files if available.
  - Build chapter marker from mp3 file duration and tagging data.
  - If metadata is not available, the final filename will use the enclosing directory's names
- Add "Cover" to final file if cover.jpg is found.
- Combine all mp3s in a directory, sorted by name.
- Convert combined mp3s into m4b file with metata.
- Cleans up temp files created after each book folder is processed.

> [!NOTE]
> This does not currently delete the old mp3 files, but I will add the feature in the near future.

# Getting Started

## Requirements
- Dependencies:
  - ffmpeg
  - jq
- Folder(s) of audiobook mp3s

# Usage
```shell
mbp16:~ user$ ./book-builder.sh

   WTF Book Builder

   Syntax: book-builder.sh <path_to_folder>

     <none>   Print this Help

mbp16:~ user$ 
```

# Future Plans
- [ ] Check file and directory names for "bad" characters that ffmpeg will not like.
- [ ] Add cleanup of old mp3 files after conversion is successful
- [X] Create a better cleanup function
- [X] Add cleanup of *.Dir.txt files
