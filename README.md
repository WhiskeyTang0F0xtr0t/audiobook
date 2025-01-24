# Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Future Plans](#future-plans)

# Overview
A script to convert directories of mp3 files to a single m4b per directory and add metadata.

Features:
- Parse .json file from audiobookshelf if it exsits in the directory.
- If the ABS json file is not found
  - Pull tag data from the mp3 files if available.
  - Build chapter marker from mp3 file duration and tagging data.
  - If metadata is not available, the final filename will use the enclosing directory's names
- Add "Cover" to final file if cover.jpg is found.
- Combine all mp3s in a directory, sorted by name.
- Convert combined mp3s into m4b file with metata.

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
- [ ] TBD
