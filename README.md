# Better Combat Effects Gold

**Current Version:** 3.30
**Updated::** 12/03/22

Better Combat Effects Gold is an extension that allows for fine tuning of when effects are enabled, disabled, removed, and added. Better Combat Effects Gold is specifically tuned to support 5eAE effects package.

Better Combat Effects Gold supports Effect Builder, a GUI for building effects

<a href="https://forge.fantasygrounds.com/shop/items/457/view" target="_blank">Effect Builder</a>
<a href="https://forge.fantasygrounds.com/shop/items/463/view" target="_blank">Effect Builder Plugin 5E</a>

## BCE Gold Modifier Tags
| Modifier | Value | Descriptors | Notes |
| --- | ---| ---| ---|
| **Add Effect** | | | |
|DMGA|(D)| [damage type]* |Apply damage when the effect is added|
|REGENA|(D)| |One time regeneration when the effect is added|
|SAVEA|(N) or [SDC]| [ability] (R) (D) (H) (M) (F) |Roll ongoing save when effect is added where (N) is a number or [SDC]|
|TREGENA|(D)| |One time regeneration to temporary HP when the effect is added|
| **Attack** | | | |
|ATKA|(-)| | ACTIVATE effect when the Actor takes the attack action|
|ATKADD|(-)|[effect] or [condition] | Add effect or condition when the Actor takes the attack action|
|ATKD|(-)| | DEACTIVATE effect when the Actor takes the attack action|
|ATKR|(-)| | REMOVE effect when the Actor takes the attack action|
|TATKHDMGS|(D)|[damage type]__*__,all,[Range]__*__| Target damages source on successful hit|
|TATKMDMGS|(D)|[damage type]__*__,all,[Range]__*__| Target damages source on miss|
| **Damage** | | | |
|DMGAT|(-)|[damage type]__*__,all,[Range]__*__| ACTIVATE effect when the Actor takes damage|
|DMGDT|(-)|[damage type]__*__,all,[Range]__*__| DEACTIVATE effect when the Actor takes damage|
|DMGRT|(-)|[damage type]__*__,all,[Range]__*__| REMOVE effect when the Actor takes damage|
|TDMGADDT|(-)| [effect] |TARGET of the attack will add an effect to the TARGET (itself) when damage is done|
|TDMGADDS|(-)| [effect] |TARGET of the attack will add an effect to the SOURCE of the attack when damage is done|
|SDMGADDT|(-)| [effect] |SOURCE of the attack will add an effect to the TARGET when damage is done|
|SDMGADDS|(-)| [effect] |SOURCE of the attack will add an effect to the SOURCE (itself) when damage is done|
|DMGR|(D)| [damage type]* ,all, [range]* |Reduce the damage taken by the specified damage type(s) by (D)|
|SAVEONDMG|(N) or [SDC] |[ability] (R) (D) (H) (M) (F)|Roll ongoing save when the Actor's takes damage where (N) is a number or [SDC]|
| **Expire Effect** | | | |
|EXPIREADD|(-)| [effect] or [condition] |Add effect or condition when this effect expires|
| **Misc** | | | |
|DC|(N)|  |(N) will be added to the [SDC] when [SDC] is automatically replaced|
|SDC|(N)| [damage type]__*__,all|(N) will be added (or subtracted) from the Actors spell save DC
|DUSE|(-)||Disable effect when a tag is used (matched)|
|DUR|(D)||Sets the duration of the effect when the effect is applied|
|ELUSIVE|(-)| |No attack roll has advantage against this Actor|
|EFFINIT|(D)| |Add an effect with initiative number|
|IMMUNE|-|CUSTOM([effect]) |Immune to an effect where [effect] is an effect in the custom effect window|
|UNFLANKABLE|(-)| |Attack rolls do not gain flanking bonuses agaist this Actor - Requires Flanking and Range extension|
| **Ongoing Damage** | | | |
|DMGOE|(D)|[damage type]* |Apply ongoing damage at the END of the Actor's turn|
|SDMGOS|(D)|[damage type]* |Apply ongoing damage at the START of the Actor's turn who applied the effect|
|SDMGOE|(D)|[damage type]* |Apply ongoing damage at the END of the Actor's turn who applied the effect|
| **Ongoing Regeneration** | | | |
|REGENE|(D)| |Apply regeneration at the END of the Actor's turn|
|SREGENS|(D)| |Apply regeneration at the START of the Actor's turn who applied the effect|
|SREGENE|(D)| |Apply regeneration at the END of the Actor's turn who applied the effect|
|STREGENS|(D)| |Apply regeneration to temporary HP at the START of the Actor's turn who applied the effect|
|STREGENE|(D)| |Apply regeneration to temporary HP at the END of the Actor's turn who applied the effect|
|TREGENS|(D)| |Apply regeneration to temporary HP at the START of the Actor's turn|
|TREGENE|(D)| |Apply regeneration to temporary HP at the END of the Actor's turn|
| **Ongoing Save** | | | |
|SAVES|(N) or [SDC]|[ability] (R) (D) (H) (M) (F) (ADV) (DIS)|Roll ongoing save at the START of the Actor's turn where (N) is a number or [SDC]|
|SAVEE|(N) or [SDC]|[ability] (R) (D) (H) (M) (F) (ADV) (DIS)|Roll ongoing save at the END of the Actor's turn where (N) is a number or [SDC]|
|SSAVES|(N) or [SDC]|[ability] (R) (D) (H) (M) (F) (ADV) (DIS)|Roll ongoing save at the START of the Actor's turn who applied the effect where (N) is a number or [SDC]|
|SSAVEE|(N) or [SDC]|[ability] (R) (D) (H) (M) (F) (ADV) (DIS)|Roll ongoing save at the END of the Actor's turn who applied the effect where (N) is a number or [SDC]|
|SAVEDMG|(D)|[damage type]* |Damage done on failed ongoing save|
|SAVEADD|(N)|[effect] or [condition] |Add effect or condition on a failed ongoing save. If N, The save must fail by N or more to add. -N the result must be N or less to add.|
|SAVEADDP|(-)|[effect] or [condition] |Add effect or condition on a successful ongoing save|
| **Rest** | | | |
|NOREST|(-)| |Actor will not gain the benefit of a short or long rest. Note: Will not prevent the actor from rolling Hit Dice|
|NORESTL|(-)| |Actor will not gain the benefit of a long rest. Note: Will not prevent the actor from rolling Hit Dice|
|RESTS|(-)| |Remove effect when the Actor takes a short rest|
|RESTL|(-)| |Remove effect when the Actor takes a short or long rest|
|SAVERESTL|(N) or [SDC]|[ability] (R) (D) (H) (M) (F) (ADV) (DIS)|Roll ongoing save when the Actor takes a long rest where (N) is a number or [SDC]|
| **Save vs Condition**| | | |
|ADVCOND|(-)|[condition] or [damage type]or [all]  |Grant advantage on a save by this actor against the defined condition or damage type|
|DISCOND|(-)|[condition] or [damage type] or [all] |Grant disadvantage on a save by this actor against the defined condition or damage type|
| **Stack**| | | |
|STACK|(-)| | Multiple of this effect is allow to be applied. The option "Allow Duplicate Effects" must be set to off|
| **Turn** | | | |
|ATURN|(-)||Enable effect on the start of any turn|
|TURNAS|(-)| | ACTIVATE effect on the START of the Actor’s turn|
|TURNDS|(-) | | DEACTIVATE effect on the START of the Actor’s turn|
|TURNRS|(-)| | REMOVE effect on the START of the Actor’s turn if current duration is 1|
|TURNAE|(-)| | ACTIVATE effect on the END of the Actor’s turn|
|TURNDE|(-)| | DEACTIVATE effect on the END of the Actor’s turn|
|TURNRE|(-)| | REMOVE effect on the END of the Actor’s turn if current duration is 1|
|STURNRS|(-)| | REMOVE effect on the START of the Actor’s turn who applied the effect if current duration is 1|
|STURNRE|(-)| | REMOVE effect on the END of the Actor’s turn who applied the effect if current duration is 1|

* **(D)** = Dice and numbers supported for value attribute
* **(N)** = Only numbers supported for value attribute
* **(-)** = Neither number nor dice supported for value attribute
* **(T)** = Effects can be targeted to only apply to modifiers against certain opponents
* **[range]** = melee, ranged
* **[damage type]** = acid, cold, fire, force, lightning, necrotic, poison, psychic, radiant, thunder, adamantine, bludgeoning, cold-forged iron, magic, piercing, silver, slashing
* **[stat]** = strength, constitution, dexterity, intelligence, wisdom, charisma
* **[ability]** = STR, CON, DEX, INT, WIS, CHA, (FORTITUDE, REFLEX, WILL) - 3.5E
* **[skill]** = any skill name
* **[effect]** = Any effect label in the custom effect list. Effect label is defined as anything before the first ; e.g. My Custom; ATKDS; "My Custom" would be the effect label
* **[condition]** = Any condition as noted above except exhaustion. Note [condition] must be all lower case
* **[SDC]** = [SDC] will be replaced by the 8 + Actors spellcasting ability modifier + [PRF]. Alternatively [SDC] can be explicitly defined such as 8,[INT],[PRF],
*  **(ADV)** advantage on ongoing save
* **(DIS)** disadvantage on ongoing save
* **(R)** will remove the save effect on a successful save
* **(D)** will disable the save effect on a successful save
* **(H)** will deal half damage on a successful ongoing save
* **(M)** will indicate this is magical so any creature will magic resistance will gain proper advantage on the save
* **(F)** will invert the roll. SAVEDMG, (R), (D), (H) will be performed on a failed save rather than successful one
* __*__ = Multiple entries of this descriptor type allowed
##### The following can be added to any effect:
**(DE)** will cause the effect to be disabled when added to the CT
**(E)** If the source of the effect drops to zero hit points, this effect will be removed

## Conditional Operators
* Not case-sensitive

| Operator |  Notes |
| --- | ---|
|CRITICAL|True if the actor has wounds that are >=75% and <100% of hit point maximum.|
|DYING|True if the actor is dying or dead.|
|HEALTHY|True if the actor has no wounds.|
|HEAVY|True if the actor has wounds that are >=50% and <75% of hit point maximum.|
|LIGHT|True if the actor has wounds that are >=0% and <25% of hit point maximum.|
|MODERATE|True if the actor has wounds that are >=25% and <50% of hit point maximum.|
|RANGE( (N) , ![faction]* , ![creature type]* , ![creature name]* )|True if the actor is within the specified range (N) of at least one other actor that is not incapacitated. Filters can be applied to match only specified.|
|TEMPHP or TEMPHP( [operation] , (N))|True if the actor has any temporary hit points or temporary hit points are greater/less than the operation.|
|WOUNDS( [operation] , (.N) )|True if the actor's wounds, as a decimal percent of their hit point maximum, is greater/less than the operation.|
* **[creature name]** = creature name to match. E.g. skeleton will match skeleton, skeleton 1, and giant skeleton
*  **[faction]** = friend, foe, neutral, enemy (different faction than this actor but not neutral), ally (same faction as this actor)
* **[operation]** =>, <=, >, <, =
* **[creature type]** = aberration, beast, celestial, construct, dragon, elemental, fey, fiend, giant, humanoid, monstrosity, ooze, plant, undead, aarakocra, bullywug, demon, devil, dragonborn, dwarf, elf, gith, gnoll, gnome, goblinoid, grimlock, halfling, human, kenku, kuo-toa, kobold, lizardfolk, living construct, merfolk, orc, quaggoth, sahuagin, shapechanger, thri-kreen, titan, troglodyte, yuan-ti, yugoloth
* __*__ = Multiple entries of this descriptor type allowed.
* A special tag **!** can be used as a kind of logical NOT.

## Examples

|Power [Source]| Effect Code | Duration/Target/Expend|Notes|
|---|---|---|---|
| Armor of Agathys [Spell] |Armor of Agathys;  IF: TEMPHP; TATKHDMGS: 5 cold,melee| Targeting=Self| |
| Belt of Frost Giant Strength [Item] |Belt of Frost Giant Strength; STR: 19-X| Targeting=Self| |
| Cloak of Displacement [Item], Displacer Beast [NPC]| Displacement; GRANTDISATK; TURNAS; DMGDT: all|Targeting=Self| |
| Deflect Missiles [Class - Monk] |Deflect Missiles; DMGR: 1d10 [MONK],[DEX],ranged,bludgeoning,piercing|Targeting=Self||
| Dominate Person [Spell] |Dominate Person; SAVEONDMG: [SDC] WIS (R)|||
| Dragon [NPC] |Frightful Presence; Frightened; SAVEE: 16 WIS (R)|||
| General Action| Dodge; TURNRS|Targeting=Self| |
| Ghoul [NPC] | Ghoul Claws; SDMGADDT: GOTU| Targeting=Self| GTOU is an effect in the custom effects list|
| Ghoul [NPC] | GOTU; Paralyzed; SAVEA: 10 CON (R); SAVEE: 10 CON (R)| | |
| Headband of Intellect [Item]|Headband of Intellect; INT: 19-X| Targeting=Self| |
| Heavy Armor Master [Feat]|Heavy Armor Master; DMGR: 3 slashing, bludgeoning, piercing, !magic| Targeting=Self| |
| Interception Fighting Style [Class - Fighter]|Interception Fighting Style; DMGR: 1d10 [PRF],all| | |
| Pact Tactics [NPC] |Pack Tactics; IFT: RANGE(5,enemy); ADVATK| Targeting=Self| |
| Turn Undead [Class - Cleric]|Turn Undead; Turned; DMGRT|Duration=1 Min| |
| Relentless Endurance [Half Orc] |Relentless Endurance; IF: DYING; HEAL: 1;| Targeting=Self Expend=On Next Action| |
| Shadow [NPC] |Shadow; SDMGADDT: Strength Drain|Target=Self|Strength Drain is an effect in the custom effects list|
| Shadow [NPC] |Strength Drain; STR: -1d4; STACK; RESTL| | |
| Shield of the 300 [Item]| Shield of the 300; TDMGADDT: Shield of the 300 Bonus| Targeting=self|Shield of the 300 Bonus is an effect in the custom effects list|
| Shield of the 300 [Item]| Shield of the 300 Bonus; AC: 1; TURNRS; STACK| ||
| Shield Wall [NPC] |Shield Wall; IF: RANGE(5,drauger guardian): GRANTDISATK;| Targeting=Self| |
| Sleep [Spell]|Sleep; Unconscious; DMGRT|Duration=1 Min| |
| Storm Desert [Class - Barbarian]|AURA: 10 all; Barbarian Raging Storm Desert; DMGA: 2 fire|Targeting=Self|Requires Aura Extension |
| Stunning Strike [Class - Monk]|Stunning Strike; Stunned; STURNRE | Duration=1 Rnd | |
| Vitriolic Sphere [Spell]|Vitriolic Sphere; DMGOE: 5d4 acid| Duration=2 Rnd | |
| Wall of Thorns [Spell]|Wall of Thorns; SAVEE: [SDC] DEX (H)(C); SAVEDMG: 7d8 slashing| | |
| Water Elemental [NPC]|Water Elemental Whelm; grappled; restrained; SDMGOS: 2d8+4 bludgeoning| | |
| Web [Spell]| Web; Restrained; SAVES: [SDC] DEX (C) | | |

### Save vs Condition
Saves against conditions will automatically be granted adv/dis based on the traits of the Actor making the saving throw. The parser will match traits with the following verbiage: words ... {advantage,disadvantage} ... words ... {saves,saving throws} ... words ... {condition(s)} ... words. Make up your own homebrew traits and have them process automagiclly.

### Replace [] with ()
When writing NPC effects, the CT doesn't process tags such as [CLASS] [PRF] [LVL]. BCE Gold will allow those tags to be written as (CLASS) (PRF) (LVL) which enables them to be processed by FG. In addition the BCE tag of [SDC] can also be written as (SDC)


### Add Effect on Damage Modifiers
Effects can be automatically added to the source or the target on the damage by either the source of the damage or the target of the damage. For this to work we need two different effects.  Example:

* Shadow; SDMGADDT: Strength Drain

The Shadow has strength drain so we put the above effect on the shadow. When the shadow deals damage, it will apply the effect "Strength Drain" to the target of the damage. The effect "Strength Drain" needs to be an effect listed in our custom effects list or conditions table. The effect looks like this:
  * Strength Drain; STR: -1d4; STACK; RESTL

### Options
| Name| Default | Options | Notes |
|---|---|---|---|
|Allow Duplicate Effects| on| off/on| When off, will not allow duplicate effects (same name, duration, actor who applied the effect) on an Actor|
|Consider Duplicate Duration| off| off/on| When on, considers Concentration duration when determining if previous concentration effects should expire|
|Experimental: Autoparse NPC Powers| off| off/on| When on, will autoparse powers and automatically create effects for: DMGOE, SDMGOS, SDMGEOE, TURNRS, TURNRE, STURNRS, STURNRE, SAVES, SAVEE|
|Restrict Concentration| off| off/on| When on, expires any previous spells with concentration (C) when a new concentration spell is cast|
|TempHP Reduction is Damage| on| off/on| For purposes of determining if something should happen if an actor takes damage. When off, if an actor takes damage that reduces their Temp HP only and NOT their HP (takes wounds), that reduction is not considered damage|
### Changelog BCE Gold vs BCE
  * IMMUNE: CUSTOM([effect]) Immune to an effect where [effect]is an effect in custom effects window
  * ATURN - Enable effect on the start of any turn
  * DUSE - Disable effect if a tag in the effect is used
  * SDC: (N) [DamageType] - Adjust the spell save DC by N
  * Save vs Condition - Saves against conditions and damage types will automatically be granted adv/dis based on the traits of the actor making the saving throw
  * ADVCOND,DISCOND: [condition] or [damage type]- Explicit advantage/disadvantage when rolling a save vs condition or damage type
  * Ongoing Saves (ADV) (DIS) - (ADV)(DIS) can be added to BCE ongoing saves to grant advantage or disadvantage
  * DUR: (N) - Dynamically set the duration of the effect at time of add. (N) can be number or dice string
  * SAVERESTL - Perform ongoing save on long rest
  * SSAVES, SAVEEE - Perform ongoing save on the source of the effects turn
  * EFFINIT: (N) - Set the initiative of the effect on add
  * NOREST, NORESTL - Actor gains no benefit from short rest/long rest
  * DMGA,DMGD,DMGR now accept damage and range types as filters
  * ATKD,ATKA,ATKR - Activate,Deactivate,Remove effect when the attack action is taken
  * ATKADD - Add custom effect when the attack action is taken
  * TATKHDMGS - Target damages source on successful hit
  * TATKMDMGS - Target damages source on miss
  * SAVEADD: (N) (effect) - Will only activate when the save fails by (N). Think of this as a "Hard fail". If (-N) will fire when the result is N or less
  * Replace FGU [] Tags - Tags like [PRF][LVL][CLASS] can now be defined in the NPC sheet effect list as (PRF)(LVL)(CLASS) to process as expected
  * (DE) - Will disable the effect on use
  * SDC - Can be written as [SDC] or (SDC)
  * (E) - Will remove the effect when the source of the effect drops to 0 HP
  * ELUSIVE - No attack roll has advantage against this Actor
  * UNFLANKABLE - Attack rolls do not gain flanking bonuses agaist this Actor - Requires Flanking and Range extension
  * Additional conditional operators (see conditional operators section)
