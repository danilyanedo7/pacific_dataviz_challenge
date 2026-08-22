script_argument <- commandArgs(trailingOnly = FALSE)
script_argument <- script_argument[startsWith(script_argument, "--file=")][1]
if (is.na(script_argument)) {
  stop("Run this file with Rscript.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)
root <- dirname(dirname(script_path))
output <- file.path(root, "_site")

qmd_body <- function(source) {
  front_matter <- regexpr(
    "(?s)\\A---\\s*\\n.*?\\n---\\s*\\n",
    source,
    perl = TRUE
  )
  if (front_matter[[1]] != 1) {
    stop("index.qmd does not start with YAML front matter", call. = FALSE)
  }

  body <- substring(source, attr(front_matter, "match.length") + 1)
  body <- trimws(body)
  opening_fence <- "```{=html}\n"
  closing_fence <- "\n```"

  if (startsWith(body, opening_fence)) {
    if (!endsWith(body, closing_fence)) {
      stop("index.qmd has an unclosed raw HTML block", call. = FALSE)
    }
    body <- substring(
      body,
      nchar(opening_fence) + 1,
      nchar(body) - nchar(closing_fence)
    )
  }
  paste0(body, "\n")
}

copy_project_directory <- function(name) {
  source <- file.path(root, name)
  if (!dir.exists(source)) {
    stop("Missing project directory: ", source, call. = FALSE)
  }
  if (!file.copy(source, output, recursive = TRUE, copy.mode = TRUE)) {
    stop("Could not copy project directory: ", name, call. = FALSE)
  }
}

copy_story_resources <- function() {
  source <- file.path(root, "story")
  destination <- file.path(output, "story")
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)

  files <- list.files(
    source,
    pattern = "\\.(csv|js)$",
    full.names = TRUE
  )
  if (length(files) && !all(file.copy(files, destination, copy.mode = TRUE))) {
    stop("Could not copy story data resources", call. = FALSE)
  }

  figures <- file.path(source, "figures")
  if (dir.exists(figures) && !file.copy(figures, destination, recursive = TRUE, copy.mode = TRUE)) {
    stop("Could not copy story figures", call. = FALSE)
  }
}

source <- paste(readLines(file.path(root, "index.qmd"), warn = FALSE), collapse = "\n")
body <- qmd_body(source)
document <- paste0(
  '<!doctype html>\n',
  '<html lang="en">\n',
  '<head>\n',
  '  <meta charset="utf-8">\n',
  '  <meta name="viewport" content="width=device-width, initial-scale=1">\n',
  '  <meta name="description" content="A visual story examining what Pacific places manage despite accounting for 0.0454% of territorial carbon dioxide emissions">\n',
  '  <title>Living with a Changing Climate Across the Pacific</title>\n',
  '  <link rel="stylesheet" href="styles.css">\n',
  '</head>\n',
  '<body>\n',
  body,
  '<script src="story/story_data.js"></script>\n',
  '<script src="story/pacific_basemap.js"></script>\n',
  '<script src="assets/story.js"></script>\n',
  '</body>\n',
  '</html>\n'
)

if (dir.exists(output)) {
  unlink(output, recursive = TRUE, force = TRUE)
}
dir.create(output, recursive = TRUE)
writeLines(document, file.path(output, "index.html"), useBytes = TRUE)
if (!file.copy(file.path(root, "styles.css"), file.path(output, "styles.css"), copy.mode = TRUE)) {
  stop("Could not copy styles.css", call. = FALSE)
}
copy_project_directory("assets")
copy_story_resources()

dir.create(file.path(output, "r"), showWarnings = FALSE)
if (!all(file.copy(
  file.path(root, "r", c("build_story.R", "render_static.R")),
  file.path(output, "r"),
  copy.mode = TRUE
))) {
  stop("Could not copy R scripts", call. = FALSE)
}
if (!all(file.copy(
  file.path(root, c("README.md", "requirements.R")),
  output,
  copy.mode = TRUE
))) {
  stop("Could not copy project documentation", call. = FALSE)
}

cat("Rendered", file.path(output, "index.html"), "\n")
