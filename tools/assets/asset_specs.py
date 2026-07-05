"""
ASSET SPEC CATALOG for tools/assets/generate.py.

Each spec is one gothic top-down asset family; `count` variants are generated (different seeds)
so the library holds a few of each to break repetition (LEVEL_PAINTING_BIBLE asymmetry law).
`replaces` names the zone_builder.gd ColorRect composite this family upgrades (pier/cargo/crane/
salt_pan/ledger_tablet). `biome_fit` guides the painter's zone placement.

target_px = long-side pixel resolution after the spotless downscale (props small, buildings large).
bg        = flat render background to key out ('green' default; 'magenta' for green/foliage subjects).
"""

# --------------------------------------------------------------------------- HARBOR (ColorRect kills)
HARBOR = [
    {"id": "pier_deck", "category": "harbor", "replaces": "pier", "target_px": 88, "count": 3,
     "subject": "a weathered grey wooden dock pier deck section, rope-lashed planks, iron nails, wet mossy boards",
     "biome_fit": ["coast", "harbor", "drowned"]},
    {"id": "pier_post", "category": "harbor", "replaces": "pier", "target_px": 40, "count": 2,
     "subject": "a single wooden dock mooring post piling, wet dark wood, rope wrapped at the top",
     "biome_fit": ["coast", "harbor"]},
    {"id": "cargo_crate", "category": "harbor", "replaces": "cargo", "target_px": 56, "count": 3,
     "subject": "a sturdy wooden shipping cargo crate, iron corner brackets, wood slats, worn labels scratched off",
     "biome_fit": ["harbor", "town", "market"]},
    {"id": "dock_crane", "category": "harbor", "replaces": "crane", "target_px": 124, "count": 2,
     "subject": "a medieval wooden harbor loading crane, tall timber mast and swinging arm, hanging hook and rope with a crate",
     "biome_fit": ["harbor", "coast"]},
    {"id": "salt_pan", "category": "harbor", "replaces": "salt_pan", "target_px": 104, "count": 2,
     "subject": "a shallow rectangular salt evaporation pan, crusted white salt rims, muddy brine, weathered wooden frame divider",
     "biome_fit": ["coast", "salt_flats"]},
    {"id": "ledger_tablet", "category": "monument", "replaces": "ledger_tablet", "target_px": 60, "count": 3,
     "subject": "an upright carved slate stone ledger tablet on a small base, rows of engraved debt runes, weathered chipped edge",
     "biome_fit": ["drowned", "archive", "town"]},
    {"id": "drowned_fence", "single": True, "category": "prop", "replaces": "drowned_fence", "target_px": 64, "count": 2, "bg": "green",
     "subject": "a leaning waterlogged wooden fence segment, rotten grey posts and rails, half sunk",
     "biome_fit": ["drowned", "bog", "coast"]},
]

# --------------------------------------------------------------------------- VILLAGE / TOWN PROPS
PROPS = [
    {"id": "barrel", "category": "prop", "target_px": 48, "count": 3,
     "subject": "a wooden barrel with iron hoops, aged staves", "biome_fit": ["town", "harbor", "tavern"]},
    {"id": "barrel_stack", "category": "prop", "target_px": 64, "count": 2,
     "subject": "a stack of three wooden barrels with iron hoops", "biome_fit": ["town", "harbor"]},
    {"id": "crate_stack", "category": "prop", "target_px": 64, "count": 2,
     "subject": "a stack of wooden crates of different sizes, iron brackets", "biome_fit": ["town", "market", "harbor"]},
    {"id": "grain_sacks", "single": True, "category": "prop", "target_px": 52, "count": 2,
     "subject": "a pile of burlap grain sacks tied with rope, patched cloth", "biome_fit": ["town", "market", "farm"]},
    {"id": "market_stall", "category": "prop", "target_px": 96, "count": 3,
     "subject": "a medieval market stall, striped cloth awning, wooden counter with goods, support poles",
     "biome_fit": ["town", "market", "capital"]},
    {"id": "village_well", "category": "prop", "target_px": 80, "count": 2,
     "subject": "a round fieldstone village well, wooden roof frame, rope and hanging bucket",
     "biome_fit": ["town", "village", "square"]},
    {"id": "wooden_fence", "single": True, "category": "prop", "target_px": 64, "count": 2, "bg": "green",
     "subject": "a weathered wooden fence segment, split-rail posts and rails", "biome_fit": ["farm", "village", "field"]},
    {"id": "stone_wall", "single": True, "category": "prop", "target_px": 64, "count": 2,
     "subject": "a low dry-stone boundary wall segment, mossy grey fieldstones", "biome_fit": ["farm", "moor", "village"]},
    {"id": "hand_cart", "category": "prop", "target_px": 72, "count": 2,
     "subject": "a wooden two-wheel hand cart with spoked wheels, empty bed", "biome_fit": ["town", "market", "farm"]},
    {"id": "hay_bale", "single": True, "category": "prop", "target_px": 48, "count": 2, "bg": "magenta",
     "subject": "a bundled straw hay bale, dry golden-brown straw tied with cord", "biome_fit": ["farm", "field", "stable"]},
    {"id": "iron_brazier", "category": "prop", "target_px": 56, "count": 2,
     "subject": "a wrought-iron standing brazier bowl with charred logs and dull orange embers, three legs",
     "biome_fit": ["town", "keep", "camp"]},
    {"id": "lantern_post", "category": "prop", "target_px": 72, "count": 2,
     "subject": "a wrought-iron street lamp post with a glass lantern housing, cold unlit", "biome_fit": ["town", "capital", "street"]},
    {"id": "signpost", "category": "prop", "target_px": 68, "count": 2,
     "subject": "a wooden crossroads signpost with two blank hanging direction boards, iron nails",
     "biome_fit": ["road", "crossroads", "village"]},
    {"id": "anvil_stump", "category": "prop", "target_px": 44, "count": 2,
     "subject": "a blacksmith iron anvil resting on a thick wooden stump", "biome_fit": ["town", "forge", "smithy"]},
    {"id": "woodpile", "single": True, "category": "prop", "target_px": 60, "count": 2,
     "subject": "a stacked firewood log pile, split logs, bark ends facing out", "biome_fit": ["village", "camp", "forest"]},
    {"id": "water_trough", "category": "prop", "target_px": 60, "count": 2,
     "subject": "a wooden water trough half full of dark water, iron banding", "biome_fit": ["farm", "stable", "village"]},
]

# --------------------------------------------------------------------------- MONUMENTS / LANDMARKS
MONUMENTS = [
    {"id": "gravestone", "category": "monument", "target_px": 48, "count": 3,
     "subject": "a weathered upright stone gravestone headstone, cracked, faint carving, moss at the base",
     "biome_fit": ["graveyard", "church", "moor"]},
    {"id": "grave_cross", "category": "monument", "target_px": 56, "count": 2,
     "subject": "a gothic stone grave cross marker, moss and lichen, slight lean", "biome_fit": ["graveyard", "church"]},
    {"id": "stone_obelisk", "category": "monument", "target_px": 100, "count": 2,
     "subject": "a tall tapering carved stone obelisk monument on a square base, weathered runes",
     "biome_fit": ["capital", "plaza", "ruin"]},
    {"id": "ruined_pillar", "category": "monument", "target_px": 84, "count": 3,
     "subject": "a broken toppled stone column ruin, cracked capital, rubble at the base", "biome_fit": ["ruin", "moor", "ancient"]},
    {"id": "roadside_shrine", "category": "monument", "target_px": 72, "count": 2,
     "subject": "a small roadside stone shrine niche with a carved figure and melted candle stubs",
     "biome_fit": ["road", "village", "moor"]},
    {"id": "hooded_statue", "category": "monument", "target_px": 96, "count": 2,
     "subject": "a weathered grey stone statue of a hooded cloaked figure on a plinth, worn face",
     "biome_fit": ["capital", "graveyard", "plaza"]},
    {"id": "stone_cairn", "category": "monument", "target_px": 48, "count": 2,
     "subject": "a stacked balanced stone cairn trail marker, grey mossy stones", "biome_fit": ["moor", "mountain", "path"]},
]

# --------------------------------------------------------------------------- BUILDINGS
BUILDINGS = [
    {"id": "cottage_thatch", "category": "building", "target_px": 116, "count": 3,
     "subject": "a small medieval cottage, timber-frame walls, steep thatched straw roof, tiny shuttered window, stone chimney",
     "biome_fit": ["village", "town", "farm"]},
    {"id": "house_stone", "category": "building", "target_px": 120, "count": 3,
     "subject": "a two-storey stone-walled medieval townhouse, dark slate roof, timber door, shuttered windows",
     "biome_fit": ["town", "capital", "street"]},
    {"id": "watchtower", "category": "building", "target_px": 128, "count": 2,
     "subject": "a round stone watchtower, narrow arrow slits, conical wooden roof, small door",
     "biome_fit": ["keep", "gate", "border"]},
    {"id": "gothic_chapel", "category": "building", "target_px": 124, "count": 2,
     "subject": "a small gothic stone chapel, pointed arched windows, a bell in a slender belfry, wooden door",
     "biome_fit": ["church", "graveyard", "village"]},
    {"id": "gothic_church", "category": "building", "target_px": 128, "count": 3,
     "subject": "a gothic stone church, tall steeple with a cross, flying buttresses, rose window, heavy doors",
     "biome_fit": ["capital", "church", "town"]},
    {"id": "blacksmith_forge", "category": "building", "target_px": 118, "count": 2,
     "subject": "a timber blacksmith forge workshop, open front, brick chimney with faint smoke, dark tiled roof",
     "biome_fit": ["town", "forge", "market"]},
    {"id": "harbor_warehouse", "category": "building", "target_px": 124, "count": 2,
     "subject": "a long low wooden harbor warehouse, big double loading doors, tarred plank walls, shallow roof",
     "biome_fit": ["harbor", "coast", "docks"]},
    {"id": "ruined_house", "category": "building", "target_px": 116, "count": 3,
     "subject": "a crumbling ruined stone house, collapsed roof, broken empty windows, ivy, rubble",
     "biome_fit": ["ruin", "deadtown", "moor"]},
    {"id": "windmill", "category": "building", "target_px": 128, "count": 2,
     "subject": "a wooden tower windmill with four cloth sails, stone base, small door",
     "biome_fit": ["farm", "field", "hill"]},
]

# --------------------------------------------------------------------------- NATURE DECALS
NATURE = [
    {"id": "tree_stump", "category": "nature", "target_px": 40, "count": 2,
     "subject": "a cut tree stump, rings visible, moss on the bark, roots", "biome_fit": ["forest", "camp", "village"]},
    {"id": "mossy_rock", "category": "nature", "target_px": 44, "count": 3,
     "subject": "a grey boulder rock with green moss patches, cracks", "biome_fit": ["forest", "moor", "coast"]},
    {"id": "dead_bush", "category": "nature", "target_px": 40, "count": 2,
     "subject": "a dry leafless dead bush, tangled grey twigs", "biome_fit": ["moor", "deadland", "bog"]},
    {"id": "fern_cluster", "single": True, "category": "nature", "target_px": 40, "count": 2, "bg": "magenta",
     "subject": "a cluster of dark green ferns, drooping fronds", "biome_fit": ["forest", "bog", "shade"]},
    {"id": "cattail_reeds", "single": True, "category": "nature", "target_px": 48, "count": 2, "bg": "magenta",
     "subject": "a clump of tall cattail marsh reeds, brown seed heads", "biome_fit": ["bog", "pond", "drowned"]},
    {"id": "mushroom_cluster", "single": True, "category": "nature", "target_px": 36, "count": 2, "bg": "magenta",
     "subject": "a cluster of pale gothic toadstool mushrooms, spotted caps", "biome_fit": ["forest", "bog", "graveyard"]},
    {"id": "toppled_log", "category": "nature", "target_px": 64, "count": 2,
     "subject": "a fallen mossy tree log, broken bark, small fungus", "biome_fit": ["forest", "bog", "camp"]},
]

# --------------------------------------------------------------------------- FISHING / BOG (owner priority: bog render rejected, placeholder boats)
FISHING = [
    {"id": "rowboat", "category": "harbor", "replaces": "boat", "target_px": 80, "count": 3,
     "subject": "a small wooden rowboat seen from above, two oars laid across, weathered brown planks, empty hull",
     "biome_fit": ["bog", "coast", "pond", "drowned"]},
    {"id": "fishing_sailboat", "category": "harbor", "replaces": "boat", "target_px": 104, "count": 2,
     "subject": "a small single-mast wooden fishing boat seen from above, furled grey canvas sail, coiled rope, weathered hull",
     "biome_fit": ["bog", "coast", "harbor"]},
    {"id": "fishing_net", "single": True, "category": "prop", "target_px": 64, "count": 3, "bg": "green",
     "subject": "a draped tangled fishing net with round cork floats and wooden buoys, knotted rope, damp",
     "biome_fit": ["bog", "harbor", "coast", "fishing"]},
    {"id": "fish_drying_rack", "single": True, "category": "prop", "target_px": 88, "count": 2,
     "subject": "a wooden fish drying rack frame, split fish and nets hung to dry on horizontal poles",
     "biome_fit": ["bog", "harbor", "fishing", "village"]},
    {"id": "lobster_pots", "single": True, "category": "prop", "target_px": 52, "count": 2,
     "subject": "a stack of woven wicker lobster crab trap pots, rope handles, damp reed weave",
     "biome_fit": ["bog", "harbor", "coast"]},
    {"id": "mooring_bollard", "category": "harbor", "target_px": 40, "count": 2,
     "subject": "a squat wooden mooring bollard post with looped rope, wet dark timber",
     "biome_fit": ["harbor", "bog", "coast"]},
]

FISHING_BUILDINGS = [
    {"id": "fisherman_cottage", "category": "building", "target_px": 114, "count": 3,
     "subject": "a small fisherman's hut cottage, weathered driftwood plank walls, a fishing net draped over one wall, "
                "low mossy thatch roof, a stubby stone chimney, a barrel by the door",
     "biome_fit": ["bog", "coast", "fishing", "village"]},
]

# --------------------------------------------------------------------------- CREATURES (animated, Wan)
CREATURE_SPECS = [
    {"id": "plague_rat", "subject": "a large mangy plague rat, matted dark brown fur, long tail, red eyes",
     "target_px": 40, "frames": 8, "wan_w": 512, "wan_h": 512, "wan_len": 41, "seed": 711,
     "states": {"walk": "scurrying forward, legs moving, tail dragging, body low"},
     "biome_fit": ["sewer", "graveyard", "deadtown", "cellar"]},
    {"id": "carrion_crow", "subject": "a big black carrion crow raven bird standing, ruffled feathers, grey beak",
     "target_px": 40, "frames": 8, "wan_w": 512, "wan_h": 512, "wan_len": 41, "seed": 733,
     "states": {"walk": "hopping and strutting forward, wings folded, head bobbing"},
     "biome_fit": ["graveyard", "moor", "ravenhollow", "battlefield"]},
]

# --------------------------------------------------------------------------- BATCHES
ALL_INANIMATE = HARBOR + FISHING + PROPS + MONUMENTS + BUILDINGS + FISHING_BUILDINGS + NATURE

# SAMPLE leads with the owner's rejected-bog priority targets (fishing) + the ColorRect kills.
SAMPLE = [
    FISHING[0],           # rowboat  (replaces the checkerboard minzinn boat)
    FISHING[1],           # fishing_sailboat
    FISHING[2],           # fishing_net
    FISHING[3],           # fish_drying_rack
    HARBOR[0],            # pier_deck (replaces the brown ColorRect pier)
    HARBOR[2],            # cargo_crate
    HARBOR[3],            # dock_crane
    HARBOR[4],            # salt_pan
    HARBOR[5],            # ledger_tablet
    PROPS[0],             # barrel
    FISHING_BUILDINGS[0], # fisherman_cottage
    BUILDINGS[0],         # cottage_thatch
]


def batch_for(name):
    return {
        "sample": SAMPLE,
        "harbor": HARBOR,
        "fishing": FISHING + FISHING_BUILDINGS,
        "props": PROPS,
        "monuments": MONUMENTS,
        "buildings": BUILDINGS,
        "nature": NATURE,
        "all": ALL_INANIMATE,
    }.get(name, SAMPLE)


SPECS = ALL_INANIMATE
