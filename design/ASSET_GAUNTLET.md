# THE ASSET GAUNTLET — military-ranked pack review (owner mandate)
Every downloaded asset pack must pass the Gauntlet before its art enters a zone. The Gauntlet is a
1,000-bot military review corps (`tools/asset_gauntlet/roster.json`) with the Vigil rank ladder:

Recruit → Lamp-Private → Lamp-Corporal → Ward-Sergeant → Stone-Lieutenant → Vein-Captain →
Marsh-Major → Gate-Colonel → Vigil-Commander → **General of the Vigil**

## The law (owner's rules, verbatim intent)
1. **Every bot in the chain must agree.** A pack ascends the rank tiers squad by squad; ONE rejection
   at any tier quarantines the pack (with written reasons). Unanimity or nothing.
2. **The final PASS is granted only by the commanding officer** (highest rank on duty).
3. **Promotion by decision quality**: when the Prime-Mandate level swarm later validates a pack in
   the wild (clean sweeps = the approvals were right; found defects = the approvers were wrong),
   every reviewer's record is settled — right calls promote, wrong calls demote. Ranks are earned.
4. **The rotation**: all 1,000 start under one General. After **3 review rounds** the sitting General
   steps down to rank 1 (Lamp-Private) and the highest-ranked bot takes command until their own
   3 rounds expire. Command is a tour, not a throne.

## Review flow per pack
- **Tier squads**: at each rank tier, a squad of on-duty bots (drawn from the roster at that rank,
  identities + records attached) runs a real inspection: style match vs the Szadi/Cainos anchors,
  palette temperature, tile-grid fit, animation completeness, license validity, level-appropriateness
  for the target zone, and Prime-Mandate beauty (would this survive the swarm?).
- Each squad files a written verdict per bot. Any NO → quarantine + reasons → pack may be re-submitted
  after remediation (recolor, re-cut) as a NEW round.
- Chain: Recruit screening → NCO fit-check → Officer deep inspection (contact sheets, in-engine test
  placement) → Commander sign-off → General's PASS stamp, recorded in the ledger with round number.
- The ledger (`roster.json`) records every review, every verdict, every promotion/demotion, and the
  rotation history. Scale knob: squads per tier are configurable; the corps is 1,000 strong and every
  enlisted bot cycles through duty across rounds.

## Integration
- No pack art is copied into `assets/` without a ledger PASS entry.
- The Prime-Mandate sweep results feed back: defects traced to a pack settle its reviewers' records.
- Already-integrated packs (Dead Swamp, craftpix undead, painterly icons, Foozle, canines) are
  submitted retroactively in Round 1-3 — if any fails, its art gets remediated or replaced.
