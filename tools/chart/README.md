# The map toolchain

The map is built with real cartography tools, not a hand-rolled rasteriser.
Five earlier attempts failed because each one invented its own renderer: a
pixel classifier over a screenshot, then GDI+ primitives, then integer
Bresenham in GDScript. A cartographer does GEOMETRY first and only then hands
finished shapes to a renderer that knows how to stroke and fill them.

## What is installed, and why each piece is there

All of it is free, and all of it is portable — nothing needs admin rights and
nothing is installed system-wide. Everything lives in the session scratchpad
under `tools/`.

| Tool | Version | Why |
|---|---|---|
| CPython (embeddable) | 3.12.7 | the only scripting runtime that has the libraries below |
| Shapely | 2.1.2 | planar geometry: `buffer`, `unary_union`, `difference`, `simplify` |
| Pillow | 12.3.0 | supersample down with Lanczos, palette quantisation |
| NumPy | 2.5.3 | the tree-density field, and the value-structure audit |
| resvg | 0.47.0 | a production SVG renderer — correct antialiasing, joins and even-odd fills |

Install them with `tools/chart/install_tools.ps1`.

## Why Shapely is the load-bearing piece

Four operations decide whether a map reads as drawn or generated, and all four
are one line each in Shapely and were impossible in every earlier attempt:

- **`buffer` a centreline** turns a road's path into its carriageway, with
  proper joins and square caps. The engraved attempt's most visible defect was
  round caps leaving lollipop blobs at every dead end.
- **`unary_union` the class** merges the whole road network into ONE polygon
  before it is stroked, so the casing is the outline of the network and breaks
  correctly at junctions. Stroking each road separately draws casings straight
  across every crossing, which is what the earlier versions did.
- **`difference`** cuts the streets out of the blocks, so a street is a VOID
  between buildings. On Nolli, Rocque and the Ordnance Survey town plans the
  street is the gap; filling it inverts the map's meaning.
- **`simplify`** is Douglas-Peucker, which is the "simplify" step of
  cartographic generalization (select, simplify, exaggerate, displace,
  symbolize). Skipping generalization is precisely why a filtered screenshot
  always reads as generated.

## The pipeline

    1. in Godot   RH_MAPDUMP=<path.json>  →  scripts/tools/map_dump.gd
                  exports the town's own authored vectors: 20 street
                  centrelines, the canals and river, field rects, 1,242
                  building footprints, 4,328 tree positions, walls, bridges.

    2. in Python  tools/chart/cartograph.py
                  geometry → SVG. Buffers, unions, differences and simplifies,
                  then emits a vector document with gradients and pattern fills.

    3. resvg      SVG → PNG at 2-3x, which Pillow then downsamples with Lanczos.
                  That supersample is what gives clean edges.

    4. the audit  the script prints the luminance interquartile span and the
                  dark-mass fraction, because "no value structure" was the
                  measured verdict on the rejected sheet (its middle half of
                  pixels spanned 6 of 100 lightness steps).

## Running it

    powershell -File tools\chart\install_tools.ps1          # once
    powershell -File tools\chart\make_sheets.ps1            # dump + draw

## One thing that keeps being got wrong

Woodland must come from tree DENSITY, never from tree presence. The city has
4,328 trees over 7168x5120 world px — a mean spacing of about 44 px — so
buffering and unioning them swallows the entire sheet. That happened twice.
Street trees and garden trees are not a forest. `_wood_from_density` counts
stems into 200 px cells, blurs the field, and keeps only what sits well above
the mean.
