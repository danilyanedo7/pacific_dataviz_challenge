# Living with a Changing Climate Across the Pacific

A visual essay created for the Pacific DataViz Challenge. The story compares Pacific and world territorial CO₂ from the same dataset, then presents cyclone event assessments and the wider track record before examining sea-surface temperature, coral heat stress, sea level, annual rainfall and crop yields, and renewable electricity generation.

The finished story is available at `_site/index.html`.

```sh
Rscript requirements.R
Rscript r/build_story.R
quarto render
```

The analysis draws on official Pacific data, Our World in Data, NOAA IBTrACS and four cyclone event assessments. Derived tables and complete source links are included.

Different measures remain separate throughout the story. Pacific and world emissions use the same territorial CO₂ field and year. Event assessments retain their own definitions, and the essay makes no individual-event attribution claim.
