# Rnotes - Utility for managing notes 

Rnotes - a minimal utility for managing notes with support for archiving and versions.

## Manifesto

Rnotes is an attempt to show and try to use the R programming language in the field of CLI utilities. In addition, I have always lacked such software, so it was decided to make it myself.

## Installation

```bash
git clone https://github.com/Ad4ndi/rn
cd rn
cp rn.R /usr/local/bin/rn
```

## Usage
```
Flags:
  -n <name> <text>             Create new note (no text for stdin)
  -e <name> <version> <text>   Edit note version
  -d <name>                    Delete note
  -D <name> <version>          Delete note version
  -l                           List all notes
  -a <name>                    Archive note
  -u <name>                    Unarchive note
  -L <name>                    List note versions
  -E <name> <version> <editor> Open note in editor
  -r <name> <version>          Read note version
  -R <name>                    Read latest note version
  -h                           Show this help
  -i                           Initialize RN

Special sequences in text:
  {{t}}               Tab
  {{n}}               New line

You can also pipe text from stdin:
  echo 'Hello' | rn -n test
  cat file.txt | rn -e test v1
```
