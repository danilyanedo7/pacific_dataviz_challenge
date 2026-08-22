#!/usr/bin/env Rscript

required_packages <- c(
  "tidyverse", "lubridate", "jsonlite", "httr2", "scales", "ragg", "systemfonts"
)

missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages)) {
  stop(
    "Missing R packages: ", paste(missing_packages, collapse = ", "),
    ". Run `Rscript requirements.R` first.",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(jsonlite)
  library(httr2)
  library(scales)
  library(ragg)
})

script_argument <- commandArgs(trailingOnly = FALSE) |>
  keep(~ str_starts(.x, "--file=")) |>
  first()

if (is.null(script_argument)) {
  stop("Run this file with Rscript.", call. = FALSE)
}

script_path <- script_argument |>
  str_remove("^--file=") |>
  normalizePath(mustWork = TRUE)

root <- dirname(dirname(script_path))
story_dir <- file.path(root, "story")
cache_dir <- Sys.getenv("WEIGHT_SOURCE_DIR", file.path(root, "data", "cache"))
figure_dir <- file.path(story_dir, "figures")
build_date <- Sys.getenv("WEIGHT_BUILD_DATE", as.character(Sys.Date()))

dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(story_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

font_dir <- file.path(root, "assets", "fonts")
tryCatch(
  systemfonts::register_font(
    name = "Satoshi",
    plain = file.path(font_dir, "Satoshi-Regular.otf"),
    bold = file.path(font_dir, "Satoshi-Bold.otf"),
    italic = file.path(font_dir, "Satoshi-Italic.otf"),
    bolditalic = file.path(font_dir, "Satoshi-BoldItalic.otf")
  ),
  error = function(error) {
    if (!str_detect(conditionMessage(error), "already exists")) {
      stop(error)
    }
  }
)

sdmx_accept <- "application/vnd.sdmx.data+csv;version=2.0.0"

sources <- list(
  climate = list(
    file = "DF_CLIMATE_CHANGE.csv",
    url = "https://stats-sdmx-disseminate.pacificdata.org/rest/data/SPC,DF_CLIMATE_CHANGE,1.0/all?dimensionAtObservation=AllDimensions",
    accept = sdmx_accept
  ),
  affected = list(
    file = "DF_SDG_11_AFFECTED.csv",
    url = "https://stats-sdmx-disseminate.pacificdata.org/rest/data/SPC,DF_SDG_11,3.0/A.VC_DSR_AFFCT.........?dimensionAtObservation=AllDimensions",
    accept = sdmx_accept
  ),
  loss = list(
    file = "DF_SDG_11_LOSS.csv",
    url = "https://stats-sdmx-disseminate.pacificdata.org/rest/data/SPC,DF_SDG_11,3.0/A.VC_DSR_AALT...._T.....?dimensionAtObservation=AllDimensions",
    accept = sdmx_accept
  ),
  power = list(
    file = "DF_POWER_GEN.csv",
    url = "https://stats-sdmx-disseminate.pacificdata.org/rest/data/SPC,DF_POWER_GEN,1.0/all?dimensionAtObservation=AllDimensions",
    accept = sdmx_accept
  ),
  renewable = list(
    file = "DF_SDG_RENEWABLE.csv",
    url = "https://stats-sdmx-disseminate.pacificdata.org/rest/data/SPC,DF_SDG,3.0/A.EG_FEC_RNEW.._T._T._T._T._T._T._Z._T?dimensionAtObservation=AllDimensions",
    accept = sdmx_accept
  ),
  owid = list(
    file = "owid-co2-data.csv",
    url = "https://raw.githubusercontent.com/owid/co2-data/master/owid-co2-data.csv"
  ),
  ibtracs = list(
    file = "ibtracs.SP.list.v04r01.csv",
    url = "https://www.ncei.noaa.gov/data/international-best-track-archive-for-climate-stewardship-ibtracs/v04r01/access/csv/ibtracs.SP.list.v04r01.csv"
  )
)

dhw_stations <- c(
  palau = "https://coralreefwatch.noaa.gov/product/vs/data/palau.txt",
  fiji = "https://coralreefwatch.noaa.gov/product/vs/data/fiji.txt",
  vanuatu = "https://coralreefwatch.noaa.gov/product/vs/data/vanuatu.txt",
  solomon_islands = "https://coralreefwatch.noaa.gov/product/vs/data/solomon_islands.txt",
  gilbert_islands = "https://coralreefwatch.noaa.gov/product/vs/data/gilbert_islands.txt",
  tuvalu = "https://coralreefwatch.noaa.gov/product/vs/data/tuvalu.txt",
  samoas = "https://coralreefwatch.noaa.gov/product/vs/data/samoas.txt",
  northern_tonga = "https://coralreefwatch.noaa.gov/product/vs/data/northern_tonga.txt"
)

places <- tribble(
  ~code, ~country, ~latitude, ~longitude, ~iso3,
  "AS", "American Samoa", -14.271, -170.132, "ASM",
  "CK", "Cook Islands", -21.237, -159.778, "COK",
  "FJ", "Fiji", -18.142, 178.442, "FJI",
  "FM", "Federated States of Micronesia", 6.918, 158.185, "FSM",
  "GU", "Guam", 13.444, 144.794, "GUM",
  "KI", "Kiribati", 1.452, 172.972, "KIR",
  "MH", "Marshall Islands", 7.116, 171.185, "MHL",
  "MP", "Northern Mariana Islands", 15.185, 145.746, "MNP",
  "NC", "New Caledonia", -22.276, 166.458, "NCL",
  "NR", "Nauru", -0.523, 166.932, "NRU",
  "NU", "Niue", -19.054, -169.867, "NIU",
  "PF", "French Polynesia", -17.552, -149.559, "PYF",
  "PG", "Papua New Guinea", -9.444, 147.180, "PNG",
  "PN", "Pitcairn Islands", -25.066, -130.101, "PCN",
  "PW", "Palau", 7.500, 134.624, "PLW",
  "SB", "Solomon Islands", -9.446, 159.973, "SLB",
  "TK", "Tokelau", -9.200, -171.850, "TKL",
  "TO", "Tonga", -21.139, -175.205, "TON",
  "TV", "Tuvalu", -8.521, 179.198, "TUV",
  "VU", "Vanuatu", -17.733, 168.327, "VUT",
  "WF", "Wallis and Futuna", -13.282, -176.175, "WLF",
  "WS", "Samoa", -13.851, -171.751, "WSM"
) |>
  mutate(longitude_pacific = if_else(longitude < 0, longitude + 360, longitude)) |>
  select(code, country, latitude, longitude, longitude_pacific, iso3)

events <- list(
  list(
    id = "pam", name = "Cyclone Pam", year = 2015L, code = "VU",
    track_sid = "2015066S08170", people_label = "65,000 people displaced",
    displaced_label = NA_character_,
    effect_label = "US$449.4 million in effects", gdp_label = "64.1% of GDP",
    source = "Vanuatu Post Disaster Needs Assessment",
    source_url = "https://www.dfat.gov.au/sites/default/files/post-disaster-needs-assessment-cyclone-pam.pdf"
  ),
  list(
    id = "winston", name = "Cyclone Winston", year = 2016L, code = "FJ",
    track_sid = "2016041S14170", people_label = "540,400 people affected",
    displaced_label = "55,195 people displaced",
    effect_label = "About US$0.9 billion in effects", gdp_label = "More than 20% of GDP",
    source = "World Bank review using the Fiji assessment",
    source_url = "https://documents1.worldbank.org/curated/en/143591490296944528/pdf/113710-NWP-PUBLIC-P159592-1701.pdf"
  ),
  list(
    id = "gita", name = "Cyclone Gita", year = 2018L, code = "TO",
    track_sid = "2018038S15172", people_label = "About 80,000 people affected",
    displaced_label = NA_character_,
    effect_label = "US$164.1 million in effects", gdp_label = "37.8% of GDP",
    source = "Tonga Post Disaster Rapid Assessment",
    source_url = "https://documents1.worldbank.org/curated/en/356451584939594362/pdf/Post-Disaster-Rapid-Assessment-Tropical-Cyclone-Gita.pdf"
  ),
  list(
    id = "harold", name = "Cyclone Harold", year = 2020L, code = "VU",
    track_sid = "2020092S09155", people_label = "About 130,000 people affected",
    displaced_label = "More than 18,000 people displaced",
    effect_label = "US$505 million in economic losses",
    gdp_label = "About 50% of GDP",
    source = "World Bank analysis of Vanuatu's disaster resilience",
    source_url = "https://documents1.worldbank.org/curated/en/289451643709153886/pdf/Dealing-with-Disasters-Analyzing-Vanuatu-s-Economy-and-Public-Finances-Through-the-Lens-of-Disaster-Resilience.pdf"
  )
)

country_lookup <- set_names(places$country, places$code)

country_name <- function(code) {
  name <- unname(country_lookup[code])
  if_else(is.na(name), code, name)
}

title_case_after_separator <- function(value) {
  characters <- str_split(str_to_lower(value), "", simplify = FALSE)[[1]]
  previous_was_letter <- FALSE
  for (index in seq_along(characters)) {
    is_letter <- str_detect(characters[[index]], "[[:alpha:]]")
    if (is_letter && !previous_was_letter) {
      characters[[index]] <- str_to_upper(characters[[index]])
    }
    previous_was_letter <- is_letter
  }
  paste0(characters, collapse = "")
}

round_safe <- function(value, digits = 4) {
  if_else(is.finite(value), round(value, digits), NA_real_)
}

download_source <- function(url, path, accept = NULL) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path) && file.info(path)$size > 0) {
    return(path)
  }

  temporary <- paste0(path, ".part")
  on.exit(unlink(temporary), add = TRUE)

  request <- request(url) |>
    req_user_agent("pacific_dataviz_challenge-data-build/2.0 (R; httr2)") |>
    req_timeout(240)

  if (!is.null(accept)) {
    request <- request |> req_headers(Accept = accept)
  }

  request |> req_perform(path = temporary)
  if (!file.rename(temporary, path)) {
    stop("Could not move downloaded file into the cache: ", path, call. = FALSE)
  }
  path
}

source_path <- function(key) {
  source <- sources[[key]]
  download_source(
    source$url,
    file.path(cache_dir, source$file),
    source$accept %||% NULL
  )
}

read_source_csv <- function(key) {
  read_csv(
    source_path(key),
    show_col_types = FALSE,
    progress = FALSE,
    name_repair = "minimal"
  )
}

climate_outputs <- function(climate) {
  climate_clean <- climate |>
    mutate(
      .source_row = row_number(),
      TIME_PERIOD = parse_double(as.character(TIME_PERIOD)),
      OBS_VALUE = parse_double(as.character(OBS_VALUE))
    )

  climate_records <- climate_clean |>
    filter(
      between(TIME_PERIOD, 1993, 2023),
      CLIMATE_CHANGE_INDICATORS %in% c("SST_ANOM", "RAIN_ANOM", "SEA_LVL")
    ) |>
    transmute(
      code = GEO_PICT,
      indicator = CLIMATE_CHANGE_INDICATORS,
      year = as.integer(TIME_PERIOD),
      value = round_safe(OBS_VALUE, 4)
    ) |>
    drop_na()

  sst_complete <- climate_records |>
    filter(indicator == "SST_ANOM") |>
    group_by(code) |>
    filter(all(1993:2023 %in% year)) |>
    summarise(
      early = mean(value[between(year, 1993, 2002)]),
      late = mean(value[between(year, 2014, 2023)]),
      .groups = "drop"
    ) |>
    mutate(
      country = country_name(code),
      early = round_safe(early, 3),
      late = round_safe(late, 3),
      change = round_safe(late - early, 3)
    ) |>
    select(code, country, early, late, change) |>
    arrange(change)

  official_ghg <- climate_clean |>
    filter(
      CLIMATE_CHANGE_INDICATORS == "GHG_EMI_CAPITA",
      GEO_PICT %in% places$code
    ) |>
    drop_na(TIME_PERIOD, OBS_VALUE) |>
    arrange(TIME_PERIOD, .source_row) |>
    group_by(GEO_PICT) |>
    slice_tail(n = 1) |>
    ungroup() |>
    transmute(
      code = GEO_PICT,
      country = country_name(code),
      year = as.integer(TIME_PERIOD),
      value = round_safe(OBS_VALUE, 2),
      .source_row
    ) |>
    arrange(value, .source_row) |>
    select(-.source_row)

  list(
    clean = climate_clean,
    records = climate_records,
    sst_summary = sst_complete,
    official_ghg = official_ghg,
    complete_sst_codes = sort(sst_complete$code)
  )
}

owid_outputs <- function(owid) {
  target_year <- 2023L
  current <- owid |>
    mutate(year = as.integer(year)) |>
    filter(year == target_year)

  pacific <- current |>
    inner_join(places |> select(code, country, iso3), by = c("iso_code" = "iso3")) |>
    drop_na(co2) |>
    transmute(
      code,
      country = country.y,
      co2 = round_safe(co2, 3),
      co2_per_capita = round_safe(co2_per_capita, 3)
    ) |>
    arrange(co2_per_capita)

  world <- current |> filter(country == "World") |> slice_head(n = 1)
  pacific_total <- sum(pacific$co2)
  comparison_names <- c("India", "World", "China", "United States", "Australia", "Qatar")

  comparisons <- current |>
    filter(country %in% comparison_names) |>
    transmute(country, value = round_safe(co2_per_capita, 3), year = target_year) |>
    arrange(match(country, comparison_names))

  list(
    pacific = pacific,
    comparisons = comparisons,
    summary = list(
      year = target_year,
      covered_entities = nrow(pacific),
      pacific_total_mt = round_safe(pacific_total, 3),
      world_total_mt = round_safe(world$co2[[1]], 3),
      share_percent = round_safe(100 * pacific_total / world$co2[[1]], 4)
    )
  )
}

read_ibtracs <- function(path) {
  columns <- c(
    "SID", "SEASON", "NAME", "ISO_TIME", "LAT", "LON", "TRACK_TYPE",
    "USA_SSHS", "USA_WIND", "WMO_WIND", "DIST2LAND"
  )
  column_names <- names(read_csv(path, n_max = 0, show_col_types = FALSE))

  read_csv(
    path,
    skip = 2,
    col_names = column_names,
    col_select = all_of(columns),
    col_types = cols(
      SID = col_character(),
      SEASON = col_double(),
      NAME = col_character(),
      ISO_TIME = col_character(),
      LAT = col_double(),
      LON = col_double(),
      TRACK_TYPE = col_character(),
      USA_SSHS = col_double(),
      USA_WIND = col_double(),
      WMO_WIND = col_double(),
      DIST2LAND = col_double()
    ),
    show_col_types = FALSE,
    progress = FALSE
  )
}

cyclone_outputs <- function(path) {
  tracks <- read_ibtracs(path) |>
    mutate(
      SEASON = parse_double(as.character(SEASON)),
      ISO_TIME = ymd_hms(ISO_TIME, quiet = TRUE),
      USA_SSHS = parse_double(as.character(USA_SSHS)),
      LON = parse_double(as.character(LON)),
      LAT = parse_double(as.character(LAT)),
      longitude_pacific = if_else(LON < 0, LON + 360, LON)
    ) |>
    filter(
      between(SEASON, 1980, 2023),
      TRACK_TYPE == "main",
      !is.na(ISO_TIME),
      hour(ISO_TIME) %% 6 == 0,
      between(longitude_pacific, 120, 300),
      between(LAT, -45, 20)
    )

  sid_order <- unique(tracks$SID)
  track_records <- map(sid_order, function(sid) {
    group <- tracks |>
      filter(SID == sid) |>
      arrange(ISO_TIME) |>
      distinct(ISO_TIME, .keep_all = TRUE)

    raw_name <- str_trim(group$NAME[[1]])
    clean_name <- if (
      is.na(raw_name) || raw_name == "" ||
        str_to_lower(raw_name) %in% c("nan", "unnamed", "not_named")
    ) {
      "Unnamed"
    } else {
      title_case_after_separator(raw_name)
    }

    points <- pmap(
      list(
        round(group$longitude_pacific, 2),
        round(group$LAT, 2),
        as.integer(group$USA_SSHS)
      ),
      function(longitude, latitude, category) {
        unname(c(longitude, latitude, category))
      }
    )

    maximum <- if (all(is.na(group$USA_SSHS))) {
      NA_integer_
    } else {
      as.integer(max(group$USA_SSHS, na.rm = TRUE))
    }

    list(
      sid = sid,
      season = as.integer(group$SEASON[[1]]),
      name = clean_name,
      max_category = maximum,
      points = points
    )
  })

  highlighted_ids <- map_chr(events, "track_sid")
  highlights <- keep(track_records, ~ .x$sid %in% highlighted_ids)

  list(
    tracks = track_records,
    highlights = highlights,
    summary = list(
      start = 1980L,
      end = 2023L,
      tracks = length(track_records),
      major_tracks = sum(map_int(track_records, ~ replace_na(.x$max_category, -9L)) >= 3L)
    )
  )
}

parse_dhw <- function(path, station_id) {
  lines <- read_lines(path, progress = FALSE)
  station_name <- str_trim(lines[[2]])
  longitude <- parse_double(str_trim(lines[[5]]))
  latitude <- parse_double(str_trim(lines[[8]]))

  annual <- lines[22:length(lines)] |>
    map_dfr(function(line) {
      values <- str_split(str_squish(line), " ")[[1]]
      if (length(values) < 10) {
        return(tibble())
      }
      tibble(
        year = suppressWarnings(as.integer(values[[1]])),
        dhw = suppressWarnings(as.numeric(values[[9]]))
      )
    }) |>
    filter(between(year, 1985, 2025), is.finite(dhw)) |>
    group_by(year) |>
    summarise(dhw = round_safe(max(dhw), 2), .groups = "drop")

  list(
    id = station_id,
    station = station_name,
    longitude = longitude,
    latitude = latitude,
    annual = annual
  )
}

dhw_outputs <- function() {
  records <- imap(dhw_stations, function(url, station_id) {
    path <- download_source(url, file.path(cache_dir, paste0("dhw_", station_id, ".txt")))
    parse_dhw(path, station_id)
  })
  unname(records[order(map_chr(records, "station"))])
}

rainfall_crop_outputs <- function(climate) {
  rain <- climate |>
    filter(CLIMATE_CHANGE_INDICATORS == "RAIN_ANOM", between(TIME_PERIOD, 1993, 2023)) |>
    transmute(code = GEO_PICT, year = as.integer(TIME_PERIOD), rainfall = OBS_VALUE)

  crop <- climate |>
    filter(CLIMATE_CHANGE_INDICATORS == "CROP_YIELD", between(TIME_PERIOD, 1993, 2023)) |>
    transmute(code = GEO_PICT, year = as.integer(TIME_PERIOD), yield = OBS_VALUE)

  paired <- inner_join(rain, crop, by = c("code", "year")) |>
    arrange(code, year) |>
    group_by(code) |>
    mutate(yield_change = 100 * (yield / lag(yield) - 1)) |>
    ungroup() |>
    filter(is.finite(rainfall), is.finite(yield_change)) |>
    mutate(
      country = country_name(code),
      rainfall = round_safe(rainfall, 2),
      yield_change = round_safe(yield_change, 2)
    ) |>
    select(code, country, year, rainfall, yield_change)

  list(
    records = paired,
    summary = list(
      pairs = nrow(paired),
      countries = n_distinct(paired$code),
      correlation = round_safe(cor(paired$rainfall, paired$yield_change), 2)
    )
  )
}

disaster_outputs <- function(affected, loss) {
  affected_series <- affected |>
    mutate(
      TIME_PERIOD = parse_double(as.character(TIME_PERIOD)),
      OBS_VALUE = parse_double(as.character(OBS_VALUE))
    ) |>
    filter(GEO_PICT %in% places$code, between(TIME_PERIOD, 2005, 2023)) |>
    drop_na(TIME_PERIOD, OBS_VALUE) |>
    transmute(
      code = GEO_PICT,
      year = as.integer(TIME_PERIOD),
      value = as.integer(round(OBS_VALUE))
    )

  loss_clean <- loss |>
    mutate(
      TIME_PERIOD = parse_double(as.character(TIME_PERIOD)),
      OBS_VALUE = parse_double(as.character(OBS_VALUE)),
      loss_usd = if_else(UNIT_MEASURE == "USD_MILLIONS", OBS_VALUE * 1e6, OBS_VALUE)
    )

  event_records <- map(events, function(event) {
    official_affected <- affected_series |>
      filter(code == event$code, year == event$year) |>
      pull(value) |>
      first()
    official_loss <- loss_clean |>
      filter(GEO_PICT == event$code, TIME_PERIOD == event$year) |>
      pull(loss_usd) |>
      first()

    c(
      event,
      list(
        country = country_name(event$code),
        official_affected = official_affected %||% NA_integer_,
        official_loss_usd = round_safe(official_loss %||% NA_real_, 0)
      )
    )
  })

  list(series = affected_series, events = event_records)
}

energy_outputs <- function(power, renewable) {
  power_records <- power |>
    mutate(OBS_VALUE = parse_double(as.character(OBS_VALUE))) |>
    filter(
      ENERGY_SOURCE %in% c("RENTOT", "NRENTOT"),
      GRID_CONN == "_T",
      UNIT_MEASURE == "GWH"
    ) |>
    group_by(GEO_PICT, TIME_PERIOD, ENERGY_SOURCE) |>
    summarise(OBS_VALUE = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = ENERGY_SOURCE, values_from = OBS_VALUE) |>
    drop_na(RENTOT, NRENTOT) |>
    filter(GEO_PICT %in% places$code) |>
    transmute(
      code = GEO_PICT,
      country = country_name(code),
      year = as.integer(TIME_PERIOD),
      share = round_safe(100 * RENTOT / (RENTOT + NRENTOT), 2),
      renewable_gwh = round_safe(RENTOT, 2),
      nonrenewable_gwh = round_safe(NRENTOT, 2)
    )

  final_energy <- renewable |>
    mutate(
      .source_row = row_number(),
      TIME_PERIOD = parse_double(as.character(TIME_PERIOD)),
      OBS_VALUE = parse_double(as.character(OBS_VALUE))
    ) |>
    filter(GEO_PICT %in% places$code) |>
    arrange(TIME_PERIOD, .source_row) |>
    group_by(GEO_PICT) |>
    slice_tail(n = 1) |>
    ungroup() |>
    transmute(
      code = GEO_PICT,
      country = country_name(code),
      year = as.integer(TIME_PERIOD),
      share = round_safe(OBS_VALUE, 2),
      .source_row
    ) |>
    arrange(year, .source_row) |>
    select(-.source_row)

  list(power = power_records, final = final_energy)
}

write_story_csvs <- function(data) {
  write_csv(data$climate_records, file.path(story_dir, "climate_records.csv"), na = "")
  write_csv(data$sst_summary, file.path(story_dir, "sst_summary.csv"), na = "")
  write_csv(data$official_ghg, file.path(story_dir, "official_ghg_per_capita.csv"), na = "")
  write_csv(data$rain_crop, file.path(story_dir, "rain_crop_pairs.csv"), na = "")
  write_csv(data$disaster_series, file.path(story_dir, "disaster_affected.csv"), na = "")
  write_csv(data$energy_power, file.path(story_dir, "renewable_power_share.csv"), na = "")

  reef_rows <- map_dfr(data$reef_dhw, function(station) {
    station$annual |> mutate(station = station$station, .before = 1)
  })
  write_csv(reef_rows, file.path(story_dir, "reef_dhw_annual.csv"), na = "")

  event_rows <- data$events |>
    map(~ .x[names(.x) != "track_sid"]) |>
    map_dfr(as_tibble)
  write_csv(event_rows, file.path(story_dir, "disaster_events.csv"), na = "")
}

theme_story <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "Satoshi") +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(face = "bold", colour = "#10202b", size = rel(1.35)),
      plot.subtitle = element_text(colour = "#65727a", margin = margin(b = 12)),
      plot.caption = element_text(colour = "#65727a", hjust = 0),
      axis.title = element_text(colour = "#65727a"),
      axis.text = element_text(colour = "#10202b"),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      strip.text = element_text(face = "bold", colour = "#10202b"),
      legend.position = "top",
      legend.justification = "left"
    )
}

save_story_plot <- function(plot, filename, width, height) {
  ggsave(
    file.path(figure_dir, filename),
    plot = plot,
    device = ragg::agg_png,
    width = width,
    height = height,
    units = "in",
    dpi = 180,
    bg = "white"
  )
}

generate_figures <- function(data) {
  emissions_plot_data <- bind_rows(
    data$owid_comparisons |>
      transmute(country, value, panel = "Territorial CO2 per person (2023)"),
    data$official_ghg |>
      transmute(country, value, panel = "Pacific GHG emissions per person (latest official value)")
  ) |>
    mutate(country = fct_reorder(country, value))

  emissions_plot <- ggplot(emissions_plot_data, aes(value, country)) +
    geom_segment(aes(x = 0, xend = value, yend = country), colour = "#bdd0d9", linewidth = 0.7) +
    geom_point(aes(colour = panel), size = 2.8, show.legend = FALSE) +
    facet_grid(panel ~ ., scales = "free_y", space = "free_y") +
    scale_colour_manual(values = c("#326f9b", "#ef725d")) +
    scale_x_continuous(trans = pseudo_log_trans(sigma = 0.1), labels = label_number()) +
    labs(
      title = "Contribution depends on the measure",
      subtitle = "Territorial CO2 and greenhouse gases remain on separate panels",
      x = "Tonnes per person (pseudo-log scale)", y = NULL,
      caption = "Sources: Our World in Data and Pacific Data Hub"
    ) +
    theme_story()
  save_story_plot(emissions_plot, "emissions_comparison.png", 9, 8)

  sst_plot <- data$sst_summary |>
    mutate(country = fct_reorder(country, change)) |>
    ggplot(aes(y = country)) +
    geom_segment(aes(x = early, xend = late, yend = country), colour = "#58a6c2", linewidth = 1.2) +
    geom_point(aes(x = early), colour = "#326f9b", size = 2.4) +
    geom_point(aes(x = late), colour = "#ef725d", size = 3) +
    labs(
      title = "Every complete ocean record moved warmer",
      subtitle = "Mean SST anomaly: 1993-2002 compared with 2014-2023",
      x = "Sea surface temperature anomaly (degrees C)", y = NULL,
      caption = "Source: Pacific Data Hub"
    ) +
    theme_story()
  save_story_plot(sst_plot, "sst_shift.png", 9, 8)

  cyclone_points <- imap_dfr(data$cyclone_tracks, function(track, index) {
    tibble(
      sid = track$sid,
      order = seq_along(track$points),
      longitude = map_dbl(track$points, 1),
      latitude = map_dbl(track$points, 2),
      major = replace_na(track$max_category, -9L) >= 3L
    )
  })

  cyclone_plot <- ggplot(cyclone_points, aes(longitude, latitude, group = sid, colour = major)) +
    geom_path(linewidth = 0.22, alpha = 0.35) +
    coord_quickmap(xlim = c(120, 300), ylim = c(-42, 20), expand = FALSE) +
    scale_colour_manual(values = c(`FALSE` = "#58a6c2", `TRUE` = "#ef725d")) +
    labs(
      title = "South Pacific cyclone tracks, 1980-2023",
      subtitle = "Coral paths reached Category 3 or above in the IBTrACS USA field",
      x = "Pacific longitude", y = "Latitude", colour = "Category 3+",
      caption = "Source: NOAA IBTrACS v4.01"
    ) +
    theme_story() +
    theme(panel.grid.major.y = element_line(colour = "#e6ecef"))
  save_story_plot(cyclone_plot, "cyclone_tracks.png", 10, 5.5)

  reef_plot_data <- map_dfr(data$reef_dhw, function(station) {
    station$annual |> mutate(station = station$station)
  })
  reef_plot <- reef_plot_data |>
    ggplot(aes(year, fct_rev(station), fill = dhw)) +
    geom_tile(width = 0.92, height = 0.88) +
    scale_fill_gradientn(
      colours = c("#18364a", "#f0cf8b", "#ef725d", "#8f1f31"),
      values = rescale(c(0, 4, 8, 20)),
      limits = c(0, 20), oob = squish
    ) +
    labs(
      title = "Coral heat stress accumulates in different years",
      subtitle = "Annual maximum Degree Heating Weeks",
      x = NULL, y = NULL, fill = "DHW",
      caption = "Source: NOAA Coral Reef Watch"
    ) +
    theme_story()
  save_story_plot(reef_plot, "reef_heat_stress.png", 10, 4.8)

  rain_plot <- data$rain_crop |>
    ggplot(aes(rainfall, yield_change)) +
    geom_hline(yintercept = 0, colour = "#bdd0d9") +
    geom_vline(xintercept = 0, colour = "#bdd0d9") +
    geom_point(colour = "#326f9b", alpha = 0.35, size = 1.7) +
    geom_smooth(method = "lm", formula = y ~ x, colour = "#ef725d", fill = "#ef725d", alpha = 0.12) +
    scale_y_continuous(trans = pseudo_log_trans(sigma = 10), labels = label_number(suffix = "%")) +
    labs(
      title = "Annual rainfall anomalies and crop-yield changes",
      subtitle = paste0("450 paired country-years; Pearson r = ", data$rain_crop_summary$correlation),
      x = "Annual rainfall anomaly (mm)", y = "Annual crop-yield change",
      caption = "Source: Pacific Data Hub"
    ) +
    theme_story()
  save_story_plot(rain_plot, "rain_crop_relationship.png", 8.5, 6)

  sea_plot <- data$climate_records |>
    filter(indicator == "SEA_LVL") |>
    mutate(country = country_name(code)) |>
    ggplot(aes(year, fct_rev(country), fill = value)) +
    geom_tile(width = 0.92, height = 0.88) +
    scale_fill_gradient2(
      low = "#275777", mid = "#ffffff", high = "#9f3741",
      midpoint = 0, breaks = c(-0.2, -0.1, 0, 0.1, 0.2)
    ) +
    labs(
      title = "Sea-level records move into higher bands",
      subtitle = "Official values are rounded to 0.1 metre",
      x = NULL, y = NULL, fill = "Metres",
      caption = "Source: Pacific Data Hub"
    ) +
    theme_story()
  save_story_plot(sea_plot, "sea_level_bands.png", 10, 7)

  energy_latest <- data$energy_power |>
    filter(year == 2023) |>
    mutate(country = fct_reorder(country, share))
  energy_plot <- ggplot(energy_latest, aes(share, country)) +
    geom_col(fill = "#58a6c2", width = 0.72) +
    geom_text(aes(label = label_percent(scale = 1, accuracy = 0.1)(share)), hjust = -0.08, size = 3.1) +
    scale_x_continuous(limits = c(0, 105), breaks = c(0, 25, 50, 75, 100), labels = label_percent(scale = 1)) +
    labs(
      title = "Renewable share of electricity generation in 2023",
      subtitle = "Recorded renewable generation as a share of total generation in 2023",
      x = NULL, y = NULL,
      caption = "Source: Pacific Data Hub"
    ) +
    theme_story()
  save_story_plot(energy_plot, "renewable_electricity.png", 9, 7)
}

message("Reading source data...")
climate <- read_source_csv("climate")
affected <- read_source_csv("affected")
loss <- read_source_csv("loss")
power <- read_source_csv("power")
renewable <- read_source_csv("renewable")
owid <- read_source_csv("owid")

climate_result <- climate_outputs(climate)
owid_result <- owid_outputs(owid)
cyclone_result <- cyclone_outputs(source_path("ibtracs"))
reef_result <- dhw_outputs()
rain_result <- rainfall_crop_outputs(climate_result$clean)
disaster_result <- disaster_outputs(affected, loss)
energy_result <- energy_outputs(power, renewable)

story_data <- list(
  generated = build_date,
  places = places,
  window = list(start = 1993L, end = 2023L),
  climate_records = climate_result$records,
  sst_summary = climate_result$sst_summary,
  complete_sst_codes = climate_result$complete_sst_codes,
  official_ghg = climate_result$official_ghg,
  owid_pacific = owid_result$pacific,
  owid_comparisons = owid_result$comparisons,
  emissions_summary = owid_result$summary,
  cyclone_tracks = cyclone_result$tracks,
  cyclone_highlights = cyclone_result$highlights,
  cyclone_summary = cyclone_result$summary,
  reef_dhw = reef_result,
  rain_crop = rain_result$records,
  rain_crop_summary = rain_result$summary,
  disaster_series = disaster_result$series,
  events = disaster_result$events,
  energy_power = energy_result$power,
  energy_final = energy_result$final
)

message("Writing derived tables...")
write_story_csvs(story_data)

story_json <- toJSON(
  story_data,
  auto_unbox = TRUE,
  dataframe = "rows",
  na = "null",
  null = "null",
  digits = NA,
  pretty = FALSE
)
write_lines(
  paste0("window.WEIGHT_STORY_DATA = ", story_json, ";"),
  file.path(story_dir, "story_data.js")
)

message("Rendering ggplot2 analysis figures...")
generate_figures(story_data)

summary <- list(
  sst_places = nrow(story_data$sst_summary),
  cyclone_tracks = story_data$cyclone_summary$tracks,
  reef_stations = length(story_data$reef_dhw),
  rain_crop_pairs = story_data$rain_crop_summary$pairs,
  events = length(story_data$events),
  power_countries = n_distinct(story_data$energy_power$code),
  ggplot_figures = length(list.files(figure_dir, pattern = "\\.png$"))
)

cat(toJSON(summary, auto_unbox = TRUE, pretty = TRUE), "\n")
