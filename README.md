# Better Combat Effects

**Current Version:** 4.2
**Updated:** 02/07/23

Better Combat Effects is an extension that allows for fine tuning of when effects are enabled, disabled, removed, and added. Don't see a ruleset? Just ask for support.

<a href="https://www.fantasygrounds.com/forums/showthread.php?68831-Better-Combat-Effects" target="_blank">Comments and Bug Reports</a>

Better Combat Effects supports Effect Builder, a GUI for building effects

<a href="https://forge.fantasygrounds.com/shop/items/457/view" target="_blank">Effect Builder</a>
<a href="https://forge.fantasygrounds.com/shop/items/463/view" target="_blank">Effect Builder Plugin 5E</a>
<a href="https://forge.fantasygrounds.com/shop/items/464/view" target="_blank">Effect Builder Plugin 3.5E/PFRPG</a>
## BCE Modifier Tags

| Color| Rulesets Supported |
|---|---|
|<span style="color:blue">Blue</span>|CoreRPG, 5E, 4E, 3.5E, PFRPG|
|<span style="color:crimson">Crimson</span>|5E, 3.5E, PFRPG|
|<span style="color:green">Green</span>|5E, 4E, 3.5E, PFRPG|
|<span style="color:magenta">Magenta</span>|4E|
|<span style="color:orange">Orange</span>|5E|
|<span style="color:purple">Purple</span>|5E, 4E|

| Modifier | Value | Descriptors | Notes | Ruleset|
| --- | ---| ---| ---| ---|
| **Add Effect** | | | | |
|<span style="color:green">DMGA</span>|(D)| [damage type]* |Apply damage when the effect is added|5E 4E 3.5E PFRPG|
|<span style="color:green">REGENA</span>|(D)| |One time regeneration when the effect is added|5E 4E 3.5E PFRPG|
|<span style="color:crimson">SAVEA</span>|(N) or [SDC]| [ability] (R) (RA) (D) (H) (M) (F) |Roll ongoing save when effect is added where (N) is a number or [SDC]|5E 3.5E PFRPG|
|<span style="color:green">TREGENA</span>|(D)| |One time regeneration to temporary HP when the effect is added|5E 4E 3.5E PFRPG|
| **Attack** | | | | |
|<span style="color:magenta">ATKDS</span>|(-)| |DEACTIVATE effect if the source of the effect is attacked|4E|
| **Damage** | | | | |
|<span style="color:green">DMGAT</span>|(-)| |Activate effect when damage is taken|5E 4E 3.5E PFRPG|
|<span style="color:green">DMGDT</span>|(-)| |Deactivate effect when damage is taken|5E 4E 3.5E PFRPG|
|<span style="color:green">DMGRT</span>|(-)| |Remove effect when damage is take|5E 4E 3.5E PFRPG|
|<span style="color:green">TDMGADDT</span>|(-)| [effect] |TARGET of the attack will add an effect to the TARGET (itself) when damage is done|5E 4E 3.5E PFRPG|
|<span style="color:green">TDMGADDS</span>|(-)| [effect] |TARGET of the attack will add an effect to the SOURCE of the attack when damage is done|5E 4E 3.5E PFRPG|
|<span style="color:green">SDMGADDT</span>|(-)| [effect] |SOURCE of the attack will add an effect to the TARGET when damage is done|5E 4E 3.5E PFRPG|
|<span style="color:green">SDMGADDS</span>|(-)| [effect] |SOURCE of the attack will add an effect to the SOURCE (itself) when damage is done|5E 4E 3.5E PFRPG|
|<span style="color:purple">DMGR</span>|(D)| [damage type]*,all, [range]* |Reduce the damage taken by the specified damage type(s) by (D)|5E 4E|
|<span style="color:crimson">SAVEONDMG</span>|(N) or [SDC]|[ability] (R) (RA) (D) (H) (M) (F)|Roll ongoing save when the  Actor's takes damage where (N) is a number or [SDC]|5E 3.5E PFRPG|
| **Expire Effect** | | | | |
|<span style="color:blue">EXPIREADD</span>|(-)| [effect] or [condition] |Add effect or condition when this effect expires|CoreRPG|
| **Misc** | | | | |
|<span style="color:orange">DC</span>|(N)|  |(N) will be added  to the [SDC] when [SDC] is automatically replaced|5E|
| **Ongoing Damage** | | | | |
|<span style="color:green">DMGOE</span>|(D)|[damage type]* |Apply ongoing damage at the END of the Actor's turn|5E 4E 3.5E PFRPG|
|<span style="color:green">SDMGOS</span>|(D)|[damage type]* |Apply ongoing damage at the START of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
|<span style="color:green">SDMGOE</span>|(D)|[damage type]* |Apply ongoing damage at the END of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
| **Ongoing Regeneration** | | | | |
|<span style="color:green">REGENE</span>|(D)| |Apply regeneration at the END of the Actor's turn|5E 4E 3.5E PFRPG|
|<span style="color:green">SREGENS</span>|(D)| |Apply regeneration at the START of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
|<span style="color:green">SREGENE</span>|(D)| |Apply regeneration at the END of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
|<span style="color:green">STREGENS</span>|(D)| |Apply regeneration to temporary HP at the START of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
|<span style="color:green">STREGENE</span>|(D)| |Apply regeneration to temporary HP at the END of the Actor's turn who applied the effect|5E 4E 3.5E PFRPG|
|<span style="color:green">TREGENS</span>|(D)| |Apply regeneration to temporary HP at the START of the Actor's turn|5E 4E 3.5E PFRPG|
|<span style="color:green">TREGENE</span>|(D)| |Apply regeneration to temporary HP at the END of the Actor's turn|5E 4E 3.5E PFRPG|
| **Ongoing Save** | | | | |
|<span style="color:crimson">SAVES</span>|(N) or [SDC]|[ability] (R) (RA) (D) (H) (M) (F)|Roll ongoing save at the START of the Actor's turn where (N) is a number or [SDC]|5E 3.5E PFRPG|
|<span style="color:crimson">SAVEE</span>|(N) or [SDC]|[ability] (R) (RA) (D) (H) (M) (F)|Roll ongoing save at the END of the Actor's turn where (N) is a number or [SDC]where (N) is a number or [SDC]|5E 3.5E PFRPG|
|<span style="color:crimson">SAVEDMG</span>|(D)|[damage type]* |Damage done on failed ongoing save|5E 3.5E PFRPG|
|<span style="color:crimson">SAVEADD</span>|(-)|[effect] or [condition] |Add effect or condition on a failed ongoing save|5E 3.5E PFRPG|
|<span style="color:crimson">SAVEADDP</span>|(-)|[effect] or [condition] |Add effect or condition on a successful ongoing save|5E 3.5E PFRPG|
| **Rest** | | | | |
|<span style="color:green">RESTS</span>|(-)| |Remove effect when the Actor takes a short rest|5E 4E 3.5E PFRPG|
|<span style="color:green">RESTL</span>|(-)| |Remove effect when the Actor takes a short or long rest|5E 4E 3.5E PFRPG|
| **Stack**| | | | |
|<span style="color:crimson">STACK</span>|(-)| | Multiple of this effect is allow to be applied. The option "Allow Duplicate Effects" must be set to off|5E 3.5E PFRPG|
| **Turn** | | | | |
|<span style="color:blue">TURNAS</span>|(-)| | ACTIVATE effect on the START of the Actor’s turn|CoreRPG|
|<span style="color:blue">TURNDS</span>|(-) | | DEACTIVATE effect on the START of the Actor’s turn|CoreRPG|
|<span style="color:blue">TURNRS</span>|(-)| | REMOVE effect on the START of the Actor’s turn if current duration is 1|CoreRPG|
|<span style="color:blue">TURNAE</span>|(-)| | ACTIVATE effect on the END of the Actor’s turn|CoreRPG|
|<span style="color:blue">TURNDE</span>|(-)| | DEACTIVATE effect on the END of the Actor’s turn|CoreRPG|
|<span style="color:blue">TURNRE</span>|(-)| | REMOVE effect on the END of the Actor’s turn if current duration is 1|CoreRPG|
|<span style="color:blue">STURNRS</span>|(-)| | REMOVE effect on the START of the Actor’s turn who applied the effect if current duration is 1|CoreRPG|
|<span style="color:blue">STURNRE</span>|(-)| | REMOVE effect on the END of the Actor’s turn who applied the effect if current duration is 1|CoreRPG|

**(D)** = Dice and numbers supported for value attribute
**(N)** = Only numbers supported for value attribute
**(-)** = Neither number nor dice supported for value attribute
**(T)** = Effects can be targeted to only apply to modifiers against certain opponents
**[range]** = melee, ranged
**[damage type]** = acid, cold, fire, force, lightning, necrotic, poison, psychic, radiant, thunder, adamantine, bludgeoning, cold-forged iron, magic, piercing, silver, slashing
**[stat]** = strength, constitution, dexterity, intelligence, wisdom, charisma
**[ability]** = STR, CON, DEX, INT, WIS, CHA, (FORTITUDE, REFLEX, WILL) - 3.5E
**[skill]** = any skill name
**[effect]** = Any effect label in the custom effect list. Effect label is defined as anything before the first ; i.e. My Custom; ATKDS; "My Custom" would be the effect label
**[condition]** = Any condition as noted above except exhaustion. Note [condition] must be all lower case
**[SDC]** = (5E only) [SDC] will be replaced by the 8 + Actors spellcasting ability modifier + [PRF]. Alternatively [SDC] can be explicitly defined such as 8,[INT],[PRF]
**(R)** will remove the save effect on a successful save.
**(RA)** will remove the save effect on any save.
**(D)** will disable the save effect on a successful save.
**(H)** will deal half damage on a successful ongoing save.
**(M)** will indicate this is magical so any creature will magic resistance will gain proper advantage on the save
**(F)** will invert the roll. SAVEDMG, (R), (RA), (D), (H) will be performed on a failed save rather than successful one
***** = Multiple entries of this descriptor type allowed

## Examples

|Power [Source]| Effect Code | Duration/Target/Expend|Notes|
|---|---|---|---|
| Belt of Frost Giant Strength [Item] |Belt of Frost Giant Strength; STR: 19-X| Targeting=Self| |
| Cloak of Displacement [Item], Displacer Beast [NPC]| Displacement; GRANTDISATK; TURNAS; DMGDT|Targeting=Self| |
| Deflect Missiles [Class - Monk] |Deflect Missiles; DMGR: 1d10 [MONK],[DEX],ranged,bludgeoning,piercing|Targeting=Self||
| Dominate Person [Spell] |Dominate Person; SAVEONDMG: [SDC] WIS (R)|||
| Dragon [NPC] |Frightful Presence; Frightened; SAVEE: 16 WIS (R)|||
| General Action| Dodge; TURNRS|Targeting=Self| |
| Ghoul [NPC] | Ghoul Claws; SDMGADDT: GOTU| Targeting=Self| GTOU is an effect in the custom effects list|
| Ghoul [NPC] | GOTU; Paralyzed; SAVEA: 10 CON (R); SAVEE: 10 CON (R)| | |
| Headband of Intellect [Item]|Headband of Intellect; INT: 19-X| Targeting=Self| |
| Heavy Armor Master [Feat]|Heavy Armor Master; DMGR: 3 slashing, bludgeoning, piercing, !magic| Targeting=Self| |
| Interception Fighting Style [Class - Fighter]|Interception Fighting Style; DMGR: 1d10 [PRF],all| | |
| Turn Undead [Class - Cleric]|Turn Undead; Turned; DMGRT|Duration=1 Min| |
| Shadow [NPC] |Shadow; SDMGADDT: Strength Drain|Target=Self|Strength Drain is an effect in the custom effects list|
| Shadow [NPC] |Strength Drain; STR: -1d4; STACK; RESTL| | |
| Shield of the 300 [Item]| Shield of the 300; TDMGADDT: Shield of the 300 Bonus| Targeting=self|Shield of the 300 Bonus is an effect in the custom effects list|
| Shield of the 300 [Item]| Shield of the 300 Bonus; AC: 1; TURNRS; STACK| ||
| Sleep [Spell]|Sleep; Unconscious; DMGRT|Duration=1 Min| |
| Storm Desert [Class - Barbarian]|AURA: 10 all; Barbarian Raging Storm Desert; DMGA: 2 fire|Targeting=Self|Requires Aura Extension |
| Stunning Strike [Class - Monk]|Stunning Strike; Stunned; STURNRE | Duration=1 Rnd | |
| Vitriolic Sphere [Spell]|Vitriolic Sphere; DMGOE: 5d4 acid| Duration=2 Rnd | |
| Wall of Thorns [Spell]|Wall of Thorns; SAVEE: [SDC] DEX (H)(C); SAVEDMG: 7d8 slashing| | |
| Water Elemental [NPC]|Water Elemental Whelm; grappled; restrained; SDMGOS: 2d8+4 bludgeoning| | |
| Web [Spell]| Web; Restrained; SAVES: [SDC] DEX (C) | | |

## Options

| Name| Default | Options | Notes | Ruleset|
|---|---|---|---|---|
|Allow Duplicate Effects| on| off/on| When off, will not allow duplicate effects (same name, duration, actor who applied the effect) on an Actor| 5E|
|Consider Duplicate Duration| off| off/on| When on, considers Concentration duration when determining if previous concentration effects should expire| 5E|
|Experimental: Autoparse NPC Powers| off| off/on| When on, will autoparse powers and automatically create effects for: DMGOE, SDMGOS, SDMGEOE, TURNRS, TURNRE, STURNRS, STURNRE, SAVES, SAVEE| 5E|
|Restrict Concentration| off| off/on| When on, expires any previous spells with concentration (C) when a new concentration spell is cast| 5E|
|TempHP Reduction is Damage| on| off/on| For purposes of determining if something should happen if an actor takes damage. When off, if an actor takes damage that reduces their Temp HP only and NOT their HP (takes wounds), that reduction is not considered damage| CoreRPG|

### Add Effect on Damage Modifiers

Effects can be automatically added to the source or the target on the damage by either the source of the damage or the target of the damage. For this to work we need two different effects.  Example:

* Shadow; SDMGADDT: Strength Drain

The Shadow has strength drain so we put the above effect on the shadow. When the shadow deals damage, it will apply the effect "Strength Drain" to the target of the damage. The effect "Strength Drain" needs to be an effect listed in our custom effects list or conditions table. The effect looks like this:

* Strength Drain; STR: -1d4; STACK; RESTL
