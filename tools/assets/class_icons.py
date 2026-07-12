"""THEMATIC CLASS SPELL ICONS (owner order 2026-07-12).

Owner amendment to the free-assets law: spell icons MAY be generated, but
each must be THEMATIC (a concrete object — the warrior swings maces and
hammers, not blue light) and each class KIT shares one palette. Fable
authors every subject below; the GPU is the brush.

Output: assets/art/icons_class/<ability_id>.png (48px, keyed, trimmed).
Wired via IconsPixel.get_tex fallback (flat dir checked before the Shikashi
registry).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate as G
import interpret as I

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "icons_class"))

PALETTES = {
    "warrior": "forged steel grey and blood red, iron rivets",
    "rogue": "gunmetal and venom violet, smoke wisps",
    "mage": "deep ice blue and arcane silver, frost sheen",
    "paladin": "aged gold and dawn ivory, holy gleam",
    "necromancer": "necrotic green and old bone, grave shadow",
    "rookwarden": "forest green and raven black, feather details",
    "druid": "amber resin and bark brown, living leaf accents",
}

# (class, ability, subject) — every subject a CONCRETE object, Fable-authored
ICONS = [
    ("warrior", "cleave", "broad war axe mid-swing"),
    ("warrior", "shield_charge", "tower shield rammed forward with motion lines"),
    ("warrior", "sunder", "warhammer head splitting an iron plate in half"),
    ("warrior", "whirlwind", "two axes blurred in a circular spin trail"),
    ("warrior", "war_cry", "carved battle horn with breath blast lines"),
    ("warrior", "iron_bulwark", "massive riveted iron kite shield"),
    ("warrior", "earthshaker", "great two-handed maul striking cracked ground"),
    ("rogue", "quick_slash", "slim curved dagger slashing"),
    ("rogue", "backstab", "dagger plunged between shoulder blades"),
    ("rogue", "shadowstep", "soft leather boot dissolving into smoke"),
    ("rogue", "noxious_vial", "cracked vial dripping venom"),
    ("rogue", "fan_of_knives", "five throwing knives fanned"),
    ("rogue", "shroud", "hooded cowl wreathed in ash"),
    ("rogue", "death_blossom", "ring of blades around a black rose"),
    ("mage", "spark", "crackling blue spark between fingers"),
    ("mage", "ice_lance", "jagged spear of clear ice"),
    ("mage", "fireball", "roiling orb of blue-white arcane fire"),
    ("mage", "flame_strike", "pillar of pale flame on a sigil"),
    ("mage", "frost_nova", "ring of ice spikes bursting outward"),
    ("mage", "blink", "silver hourglass split in two"),
    ("mage", "mana_shield", "translucent crystal dome"),
    ("mage", "cinderfall", "comet of blue cinders falling"),
    ("paladin", "hammer_blow", "consecrated warhammer with gold filigree"),
    ("paladin", "holy_smite", "gold bolt striking downward"),
    ("paladin", "judgment", "balanced golden scales over a sword"),
    ("paladin", "consecration", "gold sunburst on a stone floor sigil"),
    ("paladin", "lay_on_hands", "open gauntlet radiating soft light"),
    ("paladin", "divine_shield", "gleaming heater shield with sun emblem"),
    ("paladin", "sacred_bulwark", "gold-banded pavise shield planted"),
    ("paladin", "dawnbreak", "sunrise breaking over a blade held high"),
    ("necromancer", "soul_bolt", "green wisp torn from a skull mouth"),
    ("necromancer", "drain_life", "withered hand pulling red threads"),
    ("necromancer", "withering_curse", "cracked wax seal leaking green rot"),
    ("necromancer", "bone_nova", "burst of splintered rib bones"),
    ("necromancer", "grave_grasp", "skeletal hand clawing up through soil"),
    ("necromancer", "bone_armor", "cuirass lashed from yellowed bones"),
    ("necromancer", "raise_dead", "cracked headstone with rising green mist"),
    ("necromancer", "soul_harvest", "scythe gathering pale green wisps"),
    ("rookwarden", "loosed_arrow", "longbow at full draw, arrow nocked"),
    ("rookwarden", "piercing_shot", "bodkin arrow punching through a plate"),
    ("rookwarden", "snare_trap", "iron jaw trap set among leaves"),
    ("rookwarden", "raven_dash", "raven mid-dive, wings swept"),
    ("rookwarden", "hunters_mark", "raven skull brand glowing on bark"),
    ("rookwarden", "rook_companion", "perched rook with a keen eye"),
    ("rookwarden", "arrow_storm", "seven arrows raining diagonally"),
    ("rookwarden", "storm_of_feathers", "tornado of black raven feathers"),
    ("druid", "maul", "bear paw with unsheathed claws"),
    ("druid", "gale", "three curved wind blades slicing sideways"),
    ("druid", "thornroot", "gnarled root coiled in briars"),
    ("druid", "stormbolt", "lightning splitting an old oak"),
    ("druid", "rejuvenation", "budding sprig in cupped light"),
    ("druid", "spirit_beast", "translucent stag spirit"),
    ("druid", "bear_form", "bear head roaring in profile"),
    ("druid", "tempest", "forked lightning striking from a black storm cloud"),
]

NEG = ("blurry, 3d, photo, text, letters, watermark, bright neon rainbow, ui frame, border, "
       "multiple panels, grid, human face")


def main():
    os.makedirs(OUT, exist_ok=True)
    done = 0
    for i, (cls, aid, subject) in enumerate(ICONS):
        out_path = os.path.join(OUT, aid + ".png")
        if os.path.exists(out_path):
            continue
        pos = ("single game spell icon, %s, pixel art, centered, painterly detail, "
               "palette of %s, dark vignette background filling the square, crisp edges, no text"
               % (subject, PALETTES[cls]))
        imgs = G.run_workflow(G.sdxl_workflow(pos, NEG, 31337 + i * 11))
        if not imgs:
            print(aid, "FAILED")
            continue
        full = G._fetch_image(imgs[0]).convert("RGB")
        # spell icons are full-square tiles (dark vignette bg) — no keying;
        # downscale to 48px with nearest for the pixel read
        from PIL import Image
        icon = full.resize((48, 48), Image.LANCZOS)
        icon = icon.quantize(64).convert("RGB")
        icon.save(out_path)
        done += 1
        print(aid, "ok")
    print("generated", done)


if __name__ == "__main__":
    main()
