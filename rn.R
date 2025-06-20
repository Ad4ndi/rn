#!/usr/bin/env Rscript

RN_DIR <- path.expand("~/.rn")
NOTES_DIR <- file.path(RN_DIR, "notes")
ARCH_DIR <- file.path(RN_DIR, "archive")

proc_seq <- function(text) {
  gsub("\\{\\{t\\}\\}", "\t", gsub("\\{\\{n\\}\\}", "\n", text))
}

get_path <- function(name, ver = NULL) {
  if (is.null(ver)) {
    list(
      main = file.path(NOTES_DIR, name),
      arch = file.path(ARCH_DIR, name)
    )
  } else {
    file.path(NOTES_DIR, name, if (grepl("\\.md$", ver)) ver else paste0(ver, ".md"))
  }
}

get_ver_num <- function(vers) {
  as.numeric(sub("^v(\\d+)\\.md$", "\\1", vers))
}

next_ver <- function(dir) {
  vers <- list.files(dir, pattern = "^v\\d+\\.md$")
  if (length(vers) == 0) return("v1")
  nums <- get_ver_num(vers)
  nums <- nums[!is.na(nums)]
  if (length(nums) == 0) "v1" else paste0("v", max(nums) + 1)
}

note_op <- function(name, op, msg, err = NULL) {
  paths <- get_path(name)
  if (op(paths$main) || op(paths$arch)) {
    cat(sprintf("[v] %s\n", msg))
    return(TRUE)
  }
  if (!is.null(err)) stop(sprintf("[x] %s", err))
  FALSE
}

chk_args <- function(args, req, flag) {
  if (length(args) < req) stop(sprintf("[x] Not enough arguments for %s", flag))
}

chk_exists <- function(name, ver = NULL) {
  if (is.null(ver)) {
    paths <- get_path(name)
    if (!dir.exists(paths$main) && !dir.exists(paths$arch)) {
      stop(sprintf("[x] Note '%s' not found", name))
    }
  } else {
    path <- get_path(name, ver)
    if (!file.exists(path)) {
      stop(sprintf("[x] Version %s of note '%s' not found", ver, name))
    }
  }
}

chk_not_exists <- function(name, in_arch = FALSE) {
  path <- get_path(name)[[if (in_arch) "arch" else "main"]]
  if (dir.exists(path)) {
    stop(sprintf("[x] Note '%s' already exists%s", name, if (in_arch) " in archive" else ""))
  }
}

read_stdin <- function() {
  if (!isatty("stdin")) {
    text <- readLines("stdin", warn = FALSE)
    if (length(text) == 0) return(NULL)
    paste(text, collapse = "\n")
  } else {
    cat("Enter note text (press Ctrl+D when done):\n", file = stderr())
    flush(stderr())
    text <- readLines("stdin", warn = FALSE)
    if (length(text) == 0) return(NULL)
    paste(text, collapse = "\n")
  }
}

chk_name <- function(name) {
  if (grepl("[/\\\\]", name)) {
    stop("[x] Invalid note name: contains path separators")
  }
  if (grepl("^[.]{1,2}$", name)) {
    stop("[x] Invalid note name: cannot be . or ..")
  }
  if (nchar(name) == 0) {
    stop("[x] Invalid note name: empty name")
  }
  if (grepl("^[a-zA-Z0-9_-]+$", name)) {
    return(TRUE)
  }
  stop("[x] Invalid note name: must contain only letters, numbers, underscores and hyphens")
}

create <- function(name, text) {
  chk_name(name)
  dir <- get_path(name)$main
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ver <- next_ver(dir)
  text <- if (is.null(text)) read_stdin() else text
  if (is.null(text)) stop("[x] No text provided")
  writeLines(proc_seq(text), file.path(dir, paste0(ver, ".md")))
  cat(sprintf("[v] Created note '%s' version %s\n", name, ver))
}

edit <- function(name, ver, text) {
  chk_name(name)
  chk_exists(name, ver)
  text <- if (is.null(text)) read_stdin() else text
  if (is.null(text)) stop("[x] No text provided")
  writeLines(proc_seq(text), get_path(name, ver))
  cat(sprintf("[v] Note '%s' version %s edited\n", name, ver))
}

delete <- function(name) {
  chk_name(name)
  note_op(name, 
    function(path) if (dir.exists(path)) { unlink(path, recursive = TRUE); TRUE } else FALSE,
    sprintf("Note '%s' deleted", name),
    sprintf("Note '%s' not found in main directory or archive", name)
  )
}

del_ver <- function(name, ver) {
  chk_name(name)
  chk_exists(name, ver)
  unlink(get_path(name, ver))
  cat(sprintf("[v] Version %s of note '%s' deleted\n", ver, name))
}

list_notes <- function() {
  notes <- list.files(NOTES_DIR)
  if (length(notes) == 0) {
    cat("[v] No active notes\n")
    return()
  }
  for (i in seq_along(notes)) {
    cat(sprintf("%d | %s\n", i, notes[i]))
  }
}

archive <- function(name) {
  chk_name(name)
  paths <- get_path(name)
  chk_exists(name)
  chk_not_exists(name, TRUE)
  dir.create(ARCH_DIR, showWarnings = FALSE, recursive = TRUE)
  file.rename(paths$main, paths$arch)
  cat(sprintf("[v] Note '%s' archived\n", name))
}

unarchive <- function(name) {
  chk_name(name)
  paths <- get_path(name)
  if (!dir.exists(paths$arch)) stop(sprintf("[x] Note '%s' not found in archive", name))
  chk_not_exists(name)
  file.rename(paths$arch, paths$main)
  cat(sprintf("[v] Note '%s' unarchived\n", name))
}

list_vers <- function(name) {
  chk_name(name)
  dir <- get_path(name)$main
  chk_exists(name)
  vers <- list.files(dir, pattern = "^v\\d+\\.md$")
  if (length(vers) == 0) {
    cat(sprintf("[v] Note '%s' has no versions\n", name))
    return()
  }
  vers <- vers[order(get_ver_num(vers))]
  for (ver in vers) {
    first_line <- readLines(file.path(dir, ver), n = 1)
    cat(sprintf("%s | %s\n", gsub("\\.md$", "", ver), first_line))
  }
}

open_ed <- function(name, ver, ed) {
  chk_exists(name, ver)
  system(sprintf("%s %s", ed, get_path(name, ver)))
}

read_ver <- function(name, ver) {
  chk_name(name)
  chk_exists(name, ver)
  path <- get_path(name, ver)
  cat(readLines(path, warn = FALSE), sep = "\n")
}

read_latest <- function(name) {
  chk_name(name)
  dir <- get_path(name)$main
  chk_exists(name)
  vers <- list.files(dir, pattern = "^v\\d+\\.md$")
  if (length(vers) == 0) {
    stop(sprintf("[x] Note '%s' has no versions", name))
  }
  nums <- get_ver_num(vers)
  nums <- nums[!is.na(nums)]
  if (length(nums) == 0) {
    stop(sprintf("[x] Note '%s' has no valid versions", name))
  }
  latest_ver <- paste0("v", max(nums), ".md")
  read_ver(name, latest_ver)
}

init <- function() {
  for (dir in c(RN_DIR, NOTES_DIR, ARCH_DIR)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  cat("[v] RN initialized\n")
}

help <- function() {
  cat("Usage: rn [flags] [text]\n\n")
  cat("Flags:\n")
  cat("  -n <name> <text>             Create new note (no text for stdin)\n")
  cat("  -e <name> <version> <text>   Edit note version\n")
  cat("  -d <name>                    Delete note\n")
  cat("  -D <name> <version>          Delete note version\n")
  cat("  -l                           List all notes\n")
  cat("  -a <name>                    Archive note\n")
  cat("  -u <name>                    Unarchive note\n")
  cat("  -L <name>                    List note versions\n")
  cat("  -E <name> <version> <editor> Open note in editor\n")
  cat("  -r <name> <version>          Read note version\n")
  cat("  -R <name>                    Read latest note version\n")
  cat("  -h                           Show this help\n")
  cat("  -i                           Initialize RN\n\n")
  cat("Special sequences in text:\n")
  cat("  {{t}} - Tab\n")
  cat("  {{n}} - New line\n\n")
  cat("You can also pipe text from stdin:\n")
  cat("  echo 'Hello' | rn -n test\n")
  cat("  cat file.txt | rn -e test v1\n")
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    help()
    return()
  }
  
  switch(args[1],
    "-n" = {
      chk_args(args, 2, "-n")
      create(args[2], if (length(args) > 2) paste(args[3:length(args)], collapse = " ") else NULL)
    },
    "-e" = {
      chk_args(args, 3, "-e")
      edit(args[2], args[3], if (length(args) > 3) paste(args[4:length(args)], collapse = " ") else NULL)
    },
    "-d" = {
      chk_args(args, 2, "-d")
      delete(args[2])
    },
    "-D" = {
      chk_args(args, 3, "-D")
      del_ver(args[2], args[3])
    },
    "-l" = list_notes(),
    "-a" = {
      chk_args(args, 2, "-a")
      archive(args[2])
    },
    "-u" = {
      chk_args(args, 2, "-u")
      unarchive(args[2])
    },
    "-L" = {
      chk_args(args, 2, "-u")
      list_vers(args[2])
    },
    "-E" = {
      chk_args(args, 4, "-E")
      open_ed(args[2], args[3], args[4])
    },
    "-r" = {
      chk_args(args, 3, "-r")
      read_ver(args[2], args[3])
    },
    "-R" = {
      chk_args(args, 2, "-u")
      read_latest(args[2])
    },
    "-h" = help(),
    "-i" = init(),
    stop("[x] Unknown flag. Use -h for help")
  )
}

tryCatch(
  main(),
  error = function(e) {
    cat(sprintf("%s\n", e$message))
    quit(status = 1)
  }
) 
