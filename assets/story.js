(function () {
  "use strict";

  const data = window.WEIGHT_STORY_DATA;
  if (!data) return;

  const NS = "http://www.w3.org/2000/svg";
  const palette = {
    night: "#081725",
    paper: "#f7f3eb",
    ink: "#10202b",
    muted: "#65727a",
    mist: "#bdd0d9",
    ocean: "#58a6c2",
    blue: "#326f9b",
    coral: "#ef725d",
    scarlet: "#d74443",
    gold: "#e5b951",
    pale: "#dbe7e8"
  };

  const countryNames = new Map(data.places.map(place => [place.code, place.country]));
  const tooltip = document.createElement("div");
  tooltip.className = "tooltip";
  document.body.appendChild(tooltip);

  function svgElement(name, attributes, parent) {
    const node = document.createElementNS(NS, name);
    Object.entries(attributes || {}).forEach(([key, value]) => {
      if (value !== null && value !== undefined) node.setAttribute(key, value);
    });
    if (parent) parent.appendChild(node);
    return node;
  }

  function svgText(parent, value, x, y, className, anchor) {
    const node = svgElement("text", {
      x,
      y,
      class: className || "chart-label",
      "text-anchor": anchor || "start"
    }, parent);
    node.textContent = value;
    return node;
  }

  function makeSvg(container, width, height, label) {
    container.innerHTML = "";
    return svgElement("svg", {
      viewBox: `0 0 ${width} ${height}`,
      role: "img",
      "aria-label": label,
      preserveAspectRatio: "xMidYMid meet"
    }, container);
  }

  function linear(domainMin, domainMax, rangeMin, rangeMax) {
    return value => rangeMin + ((value - domainMin) / (domainMax - domainMin || 1)) * (rangeMax - rangeMin);
  }

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
  }

  function formatNumber(value, digits) {
    if (value === null || value === undefined || Number.isNaN(value)) return "No observation";
    return Number(value).toLocaleString("en", {
      minimumFractionDigits: digits || 0,
      maximumFractionDigits: digits || 0
    });
  }

  function signed(value, digits) {
    const output = Number(value).toFixed(digits);
    return value > 0 ? `+${output}` : output;
  }

  function showTooltip(event, html) {
    tooltip.innerHTML = html;
    tooltip.style.left = `${event.clientX}px`;
    tooltip.style.top = `${event.clientY}px`;
    tooltip.classList.add("is-visible");
  }

  function moveTooltip(event) {
    tooltip.style.left = `${event.clientX}px`;
    tooltip.style.top = `${event.clientY}px`;
  }

  function hideTooltip() {
    tooltip.classList.remove("is-visible");
  }

  function attachTooltip(node, html) {
    node.setAttribute("tabindex", "0");
    node.addEventListener("mouseenter", event => showTooltip(event, html));
    node.addEventListener("mousemove", moveTooltip);
    node.addEventListener("mouseleave", hideTooltip);
    node.addEventListener("focus", event => {
      const box = node.getBoundingClientRect();
      showTooltip({ clientX: box.left + box.width / 2, clientY: box.top + box.height / 2 }, html);
    });
    node.addEventListener("blur", hideTooltip);
  }

  function geometryPath(geometry, x, y) {
    if (!geometry) return "";
    const ringPath = ring => ring.map((point, index) =>
      `${index ? "L" : "M"}${x(point[0]).toFixed(1)},${y(point[1]).toFixed(1)}`
    ).join(" ") + "Z";
    const polygonPath = polygon => polygon.map(ringPath).join(" ");
    if (geometry.type === "Polygon") return polygonPath(geometry.coordinates);
    if (geometry.type === "MultiPolygon") return geometry.coordinates.map(polygonPath).join(" ");
    if (geometry.type === "GeometryCollection") {
      return geometry.geometries.map(item => geometryPath(item, x, y)).join(" ");
    }
    return "";
  }

  function drawBasemap(parent, x, y, options) {
    const map = window.PACIFIC_BASEMAP;
    if (!map || !map.features) return;
    map.features.forEach(feature => {
      const path = geometryPath(feature.geometry, x, y);
      if (!path) return;
      svgElement("path", {
        d: path,
        fill: options.fill,
        stroke: options.stroke,
        "stroke-width": options.strokeWidth || .7,
        "fill-rule": "evenodd",
        "vector-effect": "non-scaling-stroke"
      }, parent);
    });
  }

  function drawTitle(svg, title, subtitle, dark) {
    const titleNode = svgText(svg, title, 30, 36, "chart-title");
    titleNode.setAttribute("fill", dark ? palette.paper : palette.ink);
    const subtitleNode = svgText(svg, subtitle, 30, 61, "chart-subtitle");
    subtitleNode.setAttribute("fill", dark ? palette.mist : palette.muted);
  }

  function initEmissions() {
    const container = document.getElementById("emissions-chart");
    if (!container) return;
    const W = 1060;
    const H = 750;
    const svg = makeSvg(container, W, H, "Global carbon dioxide and Pacific greenhouse gas comparisons");
    drawTitle(svg, "A small total share with a wide per person range", "The two panels use different measures and different scales", false);

    svgText(svg, "GLOBAL TERRITORIAL CO₂ PER PERSON IN 2023", 30, 105, "chart-small").setAttribute("font-weight", "700");
    const comparisons = data.owid_comparisons;
    const xGlobal = linear(0, 42, 245, 1010);
    const ticksGlobal = [0, 10, 20, 30, 40];
    ticksGlobal.forEach(tick => {
      const x = xGlobal(tick);
      svgElement("line", { x1: x, x2: x, y1: 126, y2: 326, class: "chart-grid" }, svg);
      svgText(svg, tick, x, 347, "chart-small", "middle");
    });
    comparisons.forEach((row, index) => {
      const y = 145 + index * 31;
      svgText(svg, row.country, 225, y + 4, "chart-label", "end");
      svgElement("line", {
        x1: xGlobal(0), x2: xGlobal(row.value), y1: y, y2: y,
        stroke: row.country === "World" ? palette.gold : palette.blue,
        "stroke-width": 2,
        opacity: .72
      }, svg);
      const dot = svgElement("circle", {
        cx: xGlobal(row.value), cy: y, r: row.country === "World" ? 7 : 5.5,
        fill: row.country === "World" ? palette.gold : palette.blue
      }, svg);
      attachTooltip(dot, `<strong>${row.country}</strong><br>${row.value.toFixed(2)} tonnes of CO₂ per person in ${row.year}`);
      svgText(svg, row.value.toFixed(1), xGlobal(row.value) + 11, y + 4, "chart-small");
    });

    const share = data.emissions_summary;
    const shareGroup = svgElement("g", {}, svg);
    svgElement("rect", {
      x: 30, y: 372, width: 1000, height: 95,
      fill: "#fff", stroke: "#cfc3b3"
    }, shareGroup);
    const shareNumber = svgText(shareGroup, `${share.share_percent.toFixed(4)}%`, 58, 433, "chart-title");
    shareNumber.setAttribute("fill", palette.coral);
    shareNumber.setAttribute("font-size", "46");
    svgText(shareGroup, `${share.covered_entities} covered Pacific entities as a share of world territorial CO₂`, 300, 410, "chart-label");
    svgText(shareGroup, `${share.pacific_total_mt.toFixed(1)} million tonnes out of ${formatNumber(share.world_total_mt, 0)} million tonnes`, 300, 439, "chart-subtitle");

    svgText(svg, "OFFICIAL PACIFIC GREENHOUSE GAS EMISSIONS PER PERSON IN 2024", 30, 510, "chart-small").setAttribute("font-weight", "700");
    svgText(svg, "Logarithmic scale", 1010, 510, "chart-small", "end");
    const ghg = data.official_ghg;
    const logX = value => 300 + ((Math.log10(value) + 1) / 3) * 700;
    [.1, 1, 10, 100].forEach(tick => {
      const x = logX(tick);
      svgElement("line", { x1: x, x2: x, y1: 530, y2: 705, class: "chart-grid" }, svg);
      svgText(svg, tick, x, 727, "chart-small", "middle");
    });
    ghg.forEach((row, index) => {
      const column = index < 9 ? 0 : 1;
      const within = column ? index - 9 : index;
      const y = 549 + within * 19;
      const xStart = column ? 755 : 300;
      const x = column ? 775 + ((Math.log10(row.value) + 1) / 3) * 225 : logX(row.value);
      const labelX = column ? 750 : 285;
      svgText(svg, row.country, labelX, y + 3, "chart-small", "end");
      const dot = svgElement("circle", {
        cx: x,
        cy: y,
        r: row.code === "PW" || row.code === "NC" ? 5.7 : 4.2,
        fill: row.code === "PW" || row.code === "NC" ? palette.coral : palette.ocean
      }, svg);
      attachTooltip(dot, `<strong>${row.country}</strong><br>${row.value.toFixed(1)} tonnes of greenhouse gas emissions per person in ${row.year}`);
      if (!column) svgElement("line", { x1: xStart, x2: x, y1: y, y2: y, stroke: palette.ocean, opacity: .28 }, svg);
    });
  }

  function initSst() {
    const container = document.getElementById("sst-chart");
    if (!container) return;
    const W = 1060;
    const H = 780;
    const svg = makeSvg(container, W, H, "Change in average sea surface temperature anomaly across twenty one Pacific places");
    drawTitle(svg, "A warmer recent decade in every complete record", "Mean anomaly in 1993 through 2002 compared with 2014 through 2023", true);
    const rows = data.sst_summary;
    const x = linear(0, .7, 365, 1015);
    [0, .2, .4, .6].forEach(tick => {
      const tx = x(tick);
      svgElement("line", { x1: tx, x2: tx, y1: 92, y2: 735, class: "chart-grid" }, svg);
      svgText(svg, `${tick.toFixed(1)}°C`, tx, 758, "chart-small", "middle");
    });
    rows.forEach((row, index) => {
      const y = 110 + index * 29.5;
      svgText(svg, row.country, 330, y + 4, "chart-label", "end");
      svgElement("line", {
        x1: x(row.early), x2: x(row.late), y1: y, y2: y,
        stroke: palette.ocean, "stroke-width": 3, opacity: .68
      }, svg);
      const early = svgElement("circle", {
        cx: x(row.early), cy: y, r: 4.5,
        fill: palette.night, stroke: palette.mist, "stroke-width": 1.5
      }, svg);
      const late = svgElement("circle", {
        cx: x(row.late), cy: y, r: 6,
        fill: palette.coral
      }, svg);
      attachTooltip(early, `<strong>${row.country}</strong><br>Early mean ${signed(row.early, 2)}°C`);
      attachTooltip(late, `<strong>${row.country}</strong><br>Recent mean ${signed(row.late, 2)}°C<br>Shift ${signed(row.change, 2)}°C`);
      svgText(svg, `+${row.change.toFixed(2)}`, 1040, y + 4, "chart-small", "end");
    });
    const legendY = 82;
    svgElement("circle", { cx: 405, cy: legendY, r: 4.5, fill: palette.night, stroke: palette.mist }, svg);
    svgText(svg, "1993 through 2002", 418, legendY + 4, "chart-small");
    svgElement("circle", { cx: 555, cy: legendY, r: 6, fill: palette.coral }, svg);
    svgText(svg, "2014 through 2023", 568, legendY + 4, "chart-small");
  }

  function trackPath(track, x, y) {
    return track.points.map((point, index) =>
      `${index ? "L" : "M"}${x(point[0]).toFixed(1)},${y(point[1]).toFixed(1)}`
    ).join(" ");
  }

  function cycloneColor(category) {
    if (category === null || category < 0) return "#527385";
    if (category <= 0) return "#5a8da4";
    if (category <= 2) return palette.gold;
    return palette.coral;
  }

  function initCyclones() {
    const svg = document.getElementById("cyclone-map");
    const legend = document.getElementById("cyclone-legend");
    if (!svg || !legend) return;
    const x = linear(120, 300, 55, 965);
    const y = linear(25, -42, 45, 565);
    svgElement("rect", { x: 0, y: 0, width: 1000, height: 600, fill: palette.night }, svg);
    const grid = svgElement("g", {}, svg);
    [140, 180, 220, 260].forEach(lon => {
      svgElement("line", { x1: x(lon), x2: x(lon), y1: 45, y2: 565, stroke: "#9fc0cc", opacity: .08 }, grid);
    });
    [-30, -15, 0, 15].forEach(lat => {
      svgElement("line", { x1: 55, x2: 965, y1: y(lat), y2: y(lat), stroke: "#9fc0cc", opacity: .08 }, grid);
    });
    drawBasemap(svg, x, y, { fill: "#173449", stroke: "#5a7b8c", strokeWidth: .7 });
    svgText(svg, "SOUTH PACIFIC", 760, 330, "chart-small", "middle").setAttribute("letter-spacing", ".18em");

    const highlighted = new Set(data.cyclone_highlights.map(track => track.sid));
    const nodes = [];
    data.cyclone_tracks.forEach(track => {
      const path = svgElement("path", {
        d: trackPath(track, x, y),
        fill: "none",
        stroke: palette.ocean,
        "stroke-width": 1,
        opacity: .17,
        "stroke-linecap": "round",
        "stroke-linejoin": "round",
        "vector-effect": "non-scaling-stroke"
      }, svg);
      nodes.push({ node: path, track });
    });

    const labels = svgElement("g", {}, svg);
    data.cyclone_highlights.forEach((track, index) => {
      const point = track.points[Math.floor(track.points.length * .55)];
      const label = svgText(labels, `${track.name} ${track.season}`, x(point[0]) + 8, y(point[1]) - 8, "chart-small");
      label.setAttribute("fill", index % 2 ? palette.gold : palette.coral);
      label.style.opacity = 0;
      label.dataset.sid = track.sid;
    });

    function setView(view) {
      nodes.forEach(({ node, track }) => {
        const isHighlight = highlighted.has(track.sid);
        node.style.transition = "opacity 320ms ease, stroke 320ms ease, stroke-width 320ms ease";
        if (view === "all") {
          node.setAttribute("stroke", palette.ocean);
          node.setAttribute("stroke-width", "1");
          node.style.opacity = .17;
        } else if (view === "intensity") {
          node.setAttribute("stroke", cycloneColor(track.max_category));
          node.setAttribute("stroke-width", (track.max_category || 0) >= 3 ? "1.7" : "1");
          node.style.opacity = (track.max_category || 0) >= 3 ? .72 : .18;
        } else {
          node.setAttribute("stroke", isHighlight ? palette.coral : "#365366");
          node.setAttribute("stroke-width", isHighlight ? "3.2" : ".8");
          node.style.opacity = isHighlight ? .98 : .045;
        }
      });
      Array.from(labels.children).forEach(label => {
        label.style.opacity = view === "events" ? 1 : 0;
      });
      legend.textContent = view === "all"
        ? "508 storm tracks from 1980 through 2023"
        : view === "intensity"
          ? "Blue shows lower recorded intensity. Gold shows Categories 1 and 2. Coral shows Categories 3 through 5."
          : "Cyclones Pam, Winston, Gita and Harold are highlighted";
    }

    const steps = Array.from(document.querySelectorAll("#cyclone-scrolly .step"));
    const observer = new IntersectionObserver(entries => {
      const visible = entries.filter(entry => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible) return;
      steps.forEach(step => step.classList.toggle("is-active", step === visible.target));
      setView(visible.target.dataset.view);
    }, { threshold: [.35, .55, .75], rootMargin: "-18% 0px -18% 0px" });
    steps.forEach(step => observer.observe(step));
    steps[0].classList.add("is-active");
    setView("all");
  }

  function mixColor(a, b, amount) {
    const parse = color => color.match(/[a-f\d]{2}/gi).map(value => parseInt(value, 16));
    const first = parse(a);
    const second = parse(b);
    return `#${first.map((value, index) =>
      Math.round(value + (second[index] - value) * amount).toString(16).padStart(2, "0")
    ).join("")}`;
  }

  function dhwColor(value) {
    if (value <= 4) return mixColor("#18364a", "#f0cf8b", clamp(value / 4, 0, 1));
    if (value <= 8) return mixColor("#f0cf8b", palette.coral, (value - 4) / 4);
    return mixColor(palette.coral, "#8f1f31", clamp((value - 8) / 12, 0, 1));
  }

  function initReefs() {
    const container = document.getElementById("reef-chart");
    if (!container) return;
    const W = 1100;
    const H = 440;
    const svg = makeSvg(container, W, H, "Annual maximum Degree Heating Weeks at eight Pacific stations");
    drawTitle(svg, "Heat stress accumulates in different years", "Annual maximum Degree Heating Weeks from 1985 through 2025", true);
    const years = Array.from({ length: 41 }, (_, index) => 1985 + index);
    const x = linear(1985, 2026, 270, 1055);
    const rowHeight = 33;
    data.reef_dhw.forEach((station, index) => {
      const y = 105 + index * rowHeight;
      svgText(svg, station.station, 250, y + 19, "chart-label", "end");
      const values = new Map(station.annual.map(row => [row.year, row.dhw]));
      years.forEach(year => {
        const value = values.get(year);
        const cell = svgElement("rect", {
          x: x(year) + 1,
          y,
          width: Math.max(2, x(year + 1) - x(year) - 2),
          height: 25,
          fill: value === undefined ? "#263c49" : dhwColor(value),
          stroke: "#081725",
          "stroke-width": .6
        }, svg);
        if (value !== undefined) {
          attachTooltip(cell, `<strong>${station.station}</strong><br>${year} annual maximum<br>${value.toFixed(2)}°C weeks`);
        }
      });
    });
    [1985, 1995, 2005, 2015, 2025].forEach(year => {
      svgText(svg, year, x(year), 390, "chart-small", "middle");
    });
    const legendX = [620, 740, 860, 980];
    [0, 4, 8, 16].forEach((value, index) => {
      svgElement("rect", { x: legendX[index], y: 410, width: 26, height: 12, fill: dhwColor(value) }, svg);
      svgText(svg, `${value}°C weeks`, legendX[index] + 33, 421, "chart-small");
    });
  }

  function symlog(value) {
    return Math.sign(value) * Math.log1p(Math.abs(value) / 10);
  }

  function initRain() {
    const container = document.getElementById("rain-chart");
    if (!container) return;
    const W = 1060;
    const H = 610;
    const svg = makeSvg(container, W, H, "Rainfall anomaly compared with annual crop yield change");
    drawTitle(svg, "Four hundred and fifty country years with almost no linear pattern", "Annual rainfall anomaly and change in reported crop yield", false);
    const left = 105;
    const right = 1010;
    const top = 95;
    const bottom = 535;
    const x = linear(-60, 70, left, right);
    const yDomain = [symlog(-100), symlog(250)];
    const y = value => linear(yDomain[0], yDomain[1], bottom, top)(symlog(value));
    [-50, -25, 0, 25, 50].forEach(tick => {
      const tx = x(tick);
      svgElement("line", { x1: tx, x2: tx, y1: top, y2: bottom, class: "chart-grid" }, svg);
      svgText(svg, `${tick > 0 ? "+" : ""}${tick} mm`, tx, 562, "chart-small", "middle");
    });
    [-100, -50, -20, 0, 20, 50, 100, 250].forEach(tick => {
      const ty = y(tick);
      svgElement("line", { x1: left, x2: right, y1: ty, y2: ty, class: "chart-grid" }, svg);
      svgText(svg, `${tick > 0 ? "+" : ""}${tick}%`, 90, ty + 4, "chart-small", "end");
    });
    svgElement("line", { x1: x(0), x2: x(0), y1: top, y2: bottom, stroke: palette.ink, opacity: .42 }, svg);
    svgElement("line", { x1: left, x2: right, y1: y(0), y2: y(0), stroke: palette.ink, opacity: .42 }, svg);
    const focusCodes = new Set(["FJ", "VU", "TO", "KI"]);
    data.rain_crop.forEach(row => {
      const focus = focusCodes.has(row.code);
      const point = svgElement("circle", {
        cx: x(row.rainfall),
        cy: y(row.yield_change),
        r: focus ? 4 : 2.6,
        fill: focus ? palette.coral : palette.blue,
        opacity: focus ? .78 : .32
      }, svg);
      attachTooltip(point, `<strong>${row.country} in ${row.year}</strong><br>Rainfall anomaly ${signed(row.rainfall, 1)} mm<br>Crop yield change ${signed(row.yield_change, 1)}%`);
    });
    const badge = svgElement("g", {}, svg);
    svgElement("rect", { x: 730, y: 105, width: 250, height: 72, fill: "#fff", stroke: "#cfc3b3" }, badge);
    const corr = svgText(badge, `r = ${data.rain_crop_summary.correlation.toFixed(2)}`, 750, 147, "chart-title");
    corr.setAttribute("fill", palette.coral);
    corr.setAttribute("font-size", "34");
    svgText(badge, `${data.rain_crop_summary.countries} countries`, 885, 137, "chart-small");
    svgText(badge, `${data.rain_crop_summary.pairs} paired years`, 885, 157, "chart-small");
  }

  function seaColor(value) {
    const colors = new Map([
      [-.2, "#275777"],
      [-.1, "#4d82a0"],
      [0, "#d5d6cd"],
      [.1, "#df846c"],
      [.2, "#9f3741"]
    ]);
    return colors.get(Math.round(value * 10) / 10) || "#263c49";
  }

  function initSea() {
    const container = document.getElementById("sea-chart");
    if (!container) return;
    const W = 1080;
    const H = 760;
    const svg = makeSvg(container, W, H, "Sea level anomaly bands from 1993 through 2023");
    drawTitle(svg, "Broad bands reveal the shared upward shift", "Source values are rounded to 0.1 metre", true);
    const records = data.climate_records.filter(row => row.indicator === "SEA_LVL");
    const byCode = new Map();
    records.forEach(row => {
      if (!byCode.has(row.code)) byCode.set(row.code, new Map());
      byCode.get(row.code).set(row.year, row.value);
    });
    const codes = Array.from(byCode.keys()).sort((a, b) => countryNames.get(a).localeCompare(countryNames.get(b)));
    const years = Array.from({ length: 31 }, (_, index) => 1993 + index);
    const x = linear(1993, 2024, 300, 1035);
    codes.forEach((code, index) => {
      const y = 102 + index * 27.5;
      svgText(svg, countryNames.get(code), 280, y + 17, "chart-label", "end");
      const values = byCode.get(code);
      years.forEach(year => {
        const value = values.get(year);
        const cell = svgElement("rect", {
          x: x(year) + 1,
          y,
          width: x(year + 1) - x(year) - 2,
          height: 21,
          fill: value === undefined ? "#243847" : seaColor(value),
          stroke: palette.night,
          "stroke-width": .6
        }, svg);
        if (value !== undefined) {
          attachTooltip(cell, `<strong>${countryNames.get(code)} in ${year}</strong><br>Rounded source value ${signed(value, 1)} m`);
        }
      });
    });
    [1993, 2000, 2010, 2020, 2023].forEach(year => {
      svgText(svg, year, x(year), 704, "chart-small", "middle");
    });
    const legend = [[-.2, "−0.2 m"], [-.1, "−0.1 m"], [0, "0.0 m"], [.1, "+0.1 m"], [.2, "+0.2 m"]];
    legend.forEach((item, index) => {
      const lx = 470 + index * 112;
      svgElement("rect", { x: lx, y: 725, width: 20, height: 12, fill: seaColor(item[0]) }, svg);
      svgText(svg, item[1], lx + 27, 736, "chart-small");
    });
  }

  function drawEventTrack(svg, track) {
    const lons = track.points.map(point => point[0]);
    const lats = track.points.map(point => point[1]);
    const paddingLon = Math.max(3, (Math.max(...lons) - Math.min(...lons)) * .12);
    const paddingLat = Math.max(3, (Math.max(...lats) - Math.min(...lats)) * .2);
    const x = linear(Math.min(...lons) - paddingLon, Math.max(...lons) + paddingLon, 18, 382);
    const y = linear(Math.max(...lats) + paddingLat, Math.min(...lats) - paddingLat, 18, 172);
    svgElement("path", {
      d: trackPath(track, x, y),
      fill: "none", stroke: palette.coral, "stroke-width": 3,
      "stroke-linecap": "round", "stroke-linejoin": "round"
    }, svg);
    track.points.forEach((point, index) => {
      if (index % 5) return;
      svgElement("circle", { cx: x(point[0]), cy: y(point[1]), r: 2.2, fill: palette.gold }, svg);
    });
  }

  function initEvents() {
    const container = document.getElementById("event-cards");
    if (!container) return;
    const tracks = new Map(data.cyclone_highlights.map(track => [track.sid, track]));
    data.events.forEach(event => {
      const card = document.createElement("article");
      card.className = "event-card";
      const head = document.createElement("div");
      head.className = "event-card-head";
      head.innerHTML = `<h3>${event.name}</h3><span class="event-card-year">${event.country} ${event.year}</span>`;
      card.appendChild(head);
      const map = svgElement("svg", { viewBox: "0 0 400 190", class: "event-track", role: "img", "aria-label": `${event.name} track` });
      card.appendChild(map);
      const track = tracks.get(event.track_sid);
      if (track) drawEventTrack(map, track);
      const metrics = document.createElement("div");
      metrics.className = "event-metrics";
      metrics.innerHTML = `
        <p><strong>${event.people_label}</strong>Event assessment</p>
        <p><strong>${event.effect_label}</strong>${event.gdp_label}</p>
      `;
      card.appendChild(metrics);
      const officialAffected = event.official_affected === null ? "No annual observation" : `${formatNumber(event.official_affected)} directly affected`;
      const officialLoss = event.official_loss_usd === null ? "No annual loss observation" : `US$${formatNumber(event.official_loss_usd / 1000000, 1)} million in direct loss`;
      const official = document.createElement("div");
      official.className = "official-comparison";
      official.innerHTML = `<strong>Official annual table</strong><br>${officialAffected}<br>${officialLoss}`;
      card.appendChild(official);
      const source = document.createElement("p");
      source.className = "event-source";
      source.innerHTML = `<a href="${event.source_url}" target="_blank" rel="noopener">${event.source}</a>`;
      card.appendChild(source);
      container.appendChild(card);
    });
  }

  function initEnergy() {
    const container = document.getElementById("energy-chart");
    if (!container) return;
    const W = 1060;
    const H = 700;
    const svg = makeSvg(container, W, H, "Renewable share of electricity generation in 2023");
    drawTitle(svg, "Renewable electricity ranges from 3.1 to 94.4 percent", "Recorded renewable generation divided by renewable plus nonrenewable generation", false);
    const latest = data.energy_power.filter(row => row.year === 2023).sort((a, b) => b.share - a.share);
    const finalEnergy = new Map(data.energy_final.map(row => [row.code, row]));
    const x = linear(0, 100, 315, 1010);
    [0, 25, 50, 75, 100].forEach(tick => {
      const tx = x(tick);
      svgElement("line", { x1: tx, x2: tx, y1: 92, y2: 645, class: "chart-grid" }, svg);
      svgText(svg, `${tick}%`, tx, 674, "chart-small", "middle");
    });
    latest.forEach((row, index) => {
      const y = 110 + index * 29.5;
      svgText(svg, row.country, 290, y + 17, "chart-label", "end");
      svgElement("rect", { x: x(0), y, width: x(100) - x(0), height: 20, fill: "#ddd7cd" }, svg);
      const bar = svgElement("rect", {
        x: x(0), y, width: Math.max(1, x(row.share) - x(0)), height: 20,
        fill: row.share >= 50 ? palette.gold : palette.ocean
      }, svg);
      const final = finalEnergy.get(row.code);
      const finalText = final ? `<br>Renewable final energy ${final.share.toFixed(1)}% in ${final.year}` : "<br>No matching final energy value";
      attachTooltip(bar, `<strong>${row.country}</strong><br>Renewable electricity ${row.share.toFixed(1)}% in ${row.year}<br>${row.renewable_gwh.toFixed(1)} renewable GWh<br>${row.nonrenewable_gwh.toFixed(1)} nonrenewable GWh${finalText}`);
      svgText(svg, `${row.share.toFixed(1)}%`, Math.min(1042, x(row.share) + 8), y + 15, "chart-small");
    });
  }

  function miniSeriesSvg(records, indicator, color, bar) {
    const W = 430;
    const H = 145;
    const svg = svgElement("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
    if (!records.length) {
      svgText(svg, "No observations in the shared window", 15, 75, "chart-small");
      return svg;
    }
    const values = records.map(row => row.value);
    const minimum = Math.min(0, ...values);
    const maximum = Math.max(0, ...values);
    const x = linear(1993, 2023, 18, 415);
    const y = linear(minimum, maximum || 1, 122, 15);
    svgElement("line", { x1: 18, x2: 415, y1: y(0), y2: y(0), stroke: "#8da7b1", opacity: .42 }, svg);
    if (bar) {
      records.forEach(row => {
        svgElement("line", {
          x1: x(row.year), x2: x(row.year), y1: y(0), y2: y(row.value),
          stroke: row.value >= 0 ? color : palette.blue, "stroke-width": 6, opacity: .78
        }, svg);
      });
    } else {
      const path = records.map((row, index) => `${index ? "L" : "M"}${x(row.year)},${y(row.value)}`).join(" ");
      svgElement("path", { d: path, fill: "none", stroke: color, "stroke-width": 2.5 }, svg);
    }
    svgText(svg, "1993", 18, 141, "chart-small");
    svgText(svg, "2023", 415, 141, "chart-small", "end");
    return svg;
  }

  function seaMini(records) {
    const svg = svgElement("svg", { viewBox: "0 0 430 94", role: "img" });
    if (!records.length) {
      svgText(svg, "No observations in the shared window", 15, 50, "chart-small");
      return svg;
    }
    const x = linear(1993, 2024, 15, 415);
    records.forEach(row => {
      svgElement("rect", {
        x: x(row.year), y: 20, width: x(row.year + 1) - x(row.year) - 1,
        height: 38, fill: seaColor(row.value)
      }, svg);
    });
    svgText(svg, "1993", 15, 79, "chart-small");
    svgText(svg, "2023", 415, 79, "chart-small", "end");
    return svg;
  }

  function profileCard(title, text, graphic) {
    const card = document.createElement("article");
    card.className = "profile-card";
    const heading = document.createElement("h3");
    heading.textContent = title;
    card.appendChild(heading);
    if (text) {
      const paragraph = document.createElement("p");
      paragraph.innerHTML = text;
      card.appendChild(paragraph);
    }
    if (graphic) card.appendChild(graphic);
    return card;
  }

  function initExplorer() {
    const select = document.getElementById("place-select");
    const panel = document.getElementById("profile-panel");
    if (!select || !panel) return;
    data.places.slice().sort((a, b) => a.country.localeCompare(b.country)).forEach(place => {
      const option = document.createElement("option");
      option.value = place.code;
      option.textContent = place.country;
      select.appendChild(option);
    });
    select.value = "VU";

    function update(code) {
      const place = data.places.find(item => item.code === code);
      panel.innerHTML = "";
      const title = document.createElement("div");
      title.className = "profile-title";
      title.innerHTML = `<h3>${place.country}</h3><p>Available official observations across the story</p>`;
      panel.appendChild(title);

      const climate = data.climate_records.filter(row => row.code === code);
      const sst = climate.filter(row => row.indicator === "SST_ANOM").sort((a, b) => a.year - b.year);
      const rain = climate.filter(row => row.indicator === "RAIN_ANOM").sort((a, b) => a.year - b.year);
      const sea = climate.filter(row => row.indicator === "SEA_LVL").sort((a, b) => a.year - b.year);
      panel.appendChild(profileCard("Ocean temperature", "Sea surface temperature anomaly", miniSeriesSvg(sst, "SST_ANOM", palette.coral, false)));
      panel.appendChild(profileCard("Rainfall", "Annual rainfall anomaly", miniSeriesSvg(rain, "RAIN_ANOM", palette.ocean, true)));
      panel.appendChild(profileCard("Sea level", "Rounded annual anomaly bands", seaMini(sea)));

      const affected = data.disaster_series.filter(row => row.code === code).sort((a, b) => b.value - a.value)[0];
      const power = data.energy_power.filter(row => row.code === code).sort((a, b) => b.year - a.year)[0];
      const finalEnergy = data.energy_final.find(row => row.code === code);
      const ghg = data.official_ghg.find(row => row.code === code);
      let metrics = "";
      metrics += affected
        ? `<span class="profile-number">${formatNumber(affected.value)}</span>largest annual directly affected count in ${affected.year}`
        : `<span class="profile-number">No data</span>annual directly affected persons`;
      metrics += power
        ? `<br><br><span class="profile-number">${power.share.toFixed(1)}%</span>renewable electricity in ${power.year}`
        : `<br><br><span class="profile-number">No data</span>renewable electricity`;
      if (finalEnergy) metrics += `<br><br>${finalEnergy.share.toFixed(1)}% renewable final energy in ${finalEnergy.year}`;
      if (ghg) metrics += `<br><br>${ghg.value.toFixed(1)} tonnes of greenhouse gas emissions per person in ${ghg.year}`;
      panel.appendChild(profileCard("People and power", metrics, null));
    }

    select.addEventListener("change", () => update(select.value));
    update(select.value);
  }

  initEmissions();
  initSst();
  initCyclones();
  initReefs();
  initRain();
  initSea();
  initEvents();
  initEnergy();
  initExplorer();
})();
