# Living with a Changing Climate Across the Pacific

A visual essay created for the Pacific DataViz Challenge. The project includes the Quarto source, an offline site, derived data and a reproducible R build.

The finished story is available at `_site/index.html`.

```sh
Rscript requirements.R
Rscript r/build_story.R
quarto render
```

The analysis draws on official Pacific data, Our World in Data, NOAA IBTrACS and NOAA Coral Reef Watch. Derived tables and complete source links are included.

Different measures remain separate throughout the story. Territorial CO₂ is not combined with total greenhouse gas emissions. Disaster indicators are distinguished from individual event assessments. Missing observations remain missing.
