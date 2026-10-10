# Character data audit

Audit date: 2026-10-10.

## Sources and method

- Official released-role data: <https://raw.githubusercontent.com/ThePandemoniumInstitute/botc-release/f10cd02e3401af227ce406287eaae7bb99a06a42/resources/data/roles.json>
  (commit `f10cd02e3401af227ce406287eaae7bb99a06a42`, 2026-08-05)
- Official custom-script schema: <https://github.com/ThePandemoniumInstitute/botc-release/blob/main/script-schema.json>
- Official role references: <https://wiki.bloodontheclocktower.com/Wizard>,
  <https://wiki.bloodontheclocktower.com/Cannibal>,
  <https://wiki.bloodontheclocktower.com/Choirboy>, and
  <https://wiki.bloodontheclocktower.com/King>
- The schema defines official role IDs as lowercase alphanumeric strings. The local
  `Icon_*` names are asset identifiers, not script IDs.

The audit compared `image` values after removing the `Icon_` prefix and all
non-alphanumeric characters, then lowercasing. This produces the official IDs
for every local English entry, including `snakecharmer`, `fortuneteller`,
`spiritofivory`, and `revolutionary`.

## Identity findings

- Before this audit, a missing `roleId` fell back to the image value (for
  example, `Icon_imp`), which is not valid in official script JSON.
- The model now derives an official-format role ID from legacy `Icon_*` values.
  Existing instance IDs remain untouched.
- Loading an existing saved game with a missing or legacy `roleId` rewrites the
  same preference keys with the canonical role ID. Deep copies retain it via
  serialization.
- No duplicate derived role IDs and no local English ID absent from the official
  role list were found. The 99 German entries use the same image identifiers as
  their English counterparts, so their derived IDs match.

## Catalogue coverage

| Catalogue | Present official roles | Missing official roles |
| --- | ---: | ---: |
| Official released-role data | 181 | 0 |
| English | 181 | 0 |
| German | 99 | 82 |

The English catalogue now includes `bigwig`, `cacklejack`, `deusexfiasco`,
`godofug`, `hermit`, `hindu`, `knaves`, `pope`, `princess`, `tor`,
`ventriloquist`, `wraith`, and `zenomancer`. Their official teams are retained:
eight are `loric`, while Cacklejack is a Traveller, Deus ex Fiasco is Fabled,
Hermit is an Outsider, Princess is a Townsfolk, and Wraith is a Minion.

German is a strict subset of English: it lacks 82 English roles. This is
catalogue coverage, not an ID mismatch. No German-only image identifier was
found.

## English data findings

Resolved functional data issues:

- `wizard` now has a concise, source-backed `descriptionLong`. It describes the
  Storyteller's discretion, the balancing price and public clue without adding
  a new game rule.
- `cannibal`, `choirboy`, and `king` no longer have contradictory static night
  metadata. Their local flags and both numeric position lists are empty. A
  Cannibal wakes with the ability it has gained; Choirboy wakes only when the
  Demon kills the King; King wakes only once the dead equal or outnumber the
  living. None can be truthfully represented by an unconditional numeric slot.

Checked with no defect found:

- No English entry has an empty short description or Storyteller instruction.
- Every English image identifier resolves to a bundled image asset.
- No invalid or duplicate derived role ID was found.

Non-blocking editorial gaps:

- `acrobat`, `balloonist`, `lycanthrope`, `summoner`, and `wizard` have neither
  tips nor bluffs. The official wiki contains role guidance, but these fields
  require app-specific editorial selection and wording; they remain empty rather
  than importing or inventing prose.
- Most Travellers and Fabled entries also omit tips/bluffs. Empty bluffs for
  Fabled roles are expected because they are not player roles. Whether the
  remaining guidance fields should be written is editorial work, not a rules or
  serialization repair.
- The 13 newly added roles have only their official short ability text, team,
  reminder names and, for Princess, the official other-night reminder. No
  longer Storyteller instructions were inferred from abilities. Their image
  fields are intentionally empty: no matching local asset exists, and a
  redistribution licence for official role art was not verifiable from the
  referenced release repository. The app uses the existing neutral token
  background as a safe fallback instead of inventing an image path.

## Open questions before broader catalogue work

1. Add conditional night scheduling before treating Cannibal, Choirboy, or King
   as fully supported by the automated night flow. Their official wake-up
   conditions cannot be modelled by the current boolean/number fields.
2. Decide whether the 13 released roles missing from English and the 69
   English-only roles should be added to German; no translations were changed
   in this audit.
3. For future custom scripts, require an explicit script `id`; image-derived
   fallback is retained only to migrate this legacy catalogue.
4. Obtain an explicit artwork licence and official image files before replacing
   the neutral fallback for the 13 new roles. Add detailed Storyteller guidance
   only from an official published source.
