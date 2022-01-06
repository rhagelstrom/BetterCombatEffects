# Better Combat Effects

 **Current Version:** 2.25
**Updated::** 01/02/21

Better Combat Effects is an extension that allows for fine tuning of when effects are enabled, disabled, removed, and added. Don't see a ruleset? Just ask for support.

<a href="https://www.fantasygrounds.com/forums/showthread.php?68831-Better-Combat-Effects" target="_blank">Comments and Bug Reports</a>

## CoreRPG

---

* **EXPIREADD: [custom effect]**:  Add Effect from custom effects list when this effect expires

### Turn Modifiers

* **TURNAS** will cause an effect to ACTIVATE on the START of the PC/NPC turn. Using TURNAS along with DMGDT allows items such as the Cloak of Displacement or a Displacer Beast's Displacement to function properly.

  * Cloak of Displacement; GRANTDISATK; TURNAS; DMGDT: all

* **TURNDS** will cause an effect to DEACTIVATE on the START of the PC/NPC turn.

* **TURNRS** will cause the effect to be REMOVED on the START of the PC/NPC turn if current duration is 1. 

  * Dodge; TURNRS

* **TURNAE** will cause an effect to ACTIVATE on the END of the PC/NPC turn.

* **TURNDE** will cause an effect to DEACTIVATE on the END of the PC/NPC turn.

* **TURNRE** will cause the effect to be REMOVED at the END of the PC/NPC turn if current duration is 1. This is useful for conditions like poison to be removed but do not require a saving throw.

  * Poisoned; Poisoned; TURNRE

* **STURNRS** will cause the effect to be REMOVED on the START of the source of the effects turn if current duration is 1. This is useful for conditions with the text "until the start of your next turn"

* **STURNRE** will cause the effect to be REMOVED on the END of the source of the effects turn if current duration is 1. This is useful for conditions with the text "until the end of your turn"

  * Stunning Strike; Stunned; STURNRE

* **(DE)** will cause the effect to be disabled when added to the CT 

## 5E/4E/3.5E/PFRPG

---

### Rest Tags

**RESTL**, for long rest and **RESTS** for short rest. These tags will REMOVE an effect on short rest or long rest. Effects with RESTS will also be removed on long rest.

* True Seeing; VISION: 120 truesight; RESTS
* Mage Armor; AC: 3; RESTL

### Automatic Ability Score

Items that adjust an ability score to a number. Item of Giant Strength, Headband of Intellect, are automatically calculated when added to the PC/NPC on the combat tracker if they use the **-X** format. The effect will need to be deleted the effect and re-added it on an ASI to have the value recalculated.

* Belt of Frost Giant Strength; STR: 19-X;
* Headband of Intellect; INT: 19-X;

Additionally, effects that use ability score modifiers in the format [ ABILITYSCORE ] are handled automatically. The score between [ ] is replaced with the correct modifier

* Lifedrinker;DMG:[CHA], melee

### STACK

**5E:** Multiple identical effects are now ignored. If a PC/NPC is poisoned, it won't be poisoned again. This however can be overridden with the STACK tag for effects that need to stack such as a shadow's Strength Drain. The ignore duplicates can be disabled in the options menu.

**Other Rulesets** Multiple of the same effect can be applied by using the STACK tag

* Strength Drain; STR: -1d4; STACK; RESTL

### Dice in Effect

Adding effect with a dice string automatically rolls the dice when the effect is applied. The Shadow's Strength Drain can now be automated. Only die that modify ability scores (STR,DEX,CON,WIS,INT,CHA) will be rolled

### Damage Modifiers

* **DMGAT: (N) [damage type(s)][Range]** will cause an effect to ACTIVATE when the PC/NPC takes damage.

* **DMGDT: (N) [damage type(s)][Range]** will cause an effect to DEACTIVATE when the PC/NPC takes damage. Allows items like Cloak of Displacement to function properly.

  * Cloak of Displacement; GRANTDISATK; TURNAS; DMGDT: all

* **DMGRT: (N) [damage type(s)][Range]** The effect will be REMOVED from the PC/NPC if they take damage. This is useful for turn undead or sleep

  * Turn Undead; Turned; DMGRT: all
  * Sleep; Unconscious; DMGRT: all


### Dynamic Effect Duration

* **DUR: (N)** Sets the duration of the effect when the effect is applied. (N) can be number or dice string

### Add Effect on Damage Modifiers

Effects can be automatically added to the source or the target on the damage by either the source of the damage or the target of the damage. For this to work we need two different effects.  Example:

  * Shadow; SDMGADDT: Strength Drain

The Shadow has strength drain so we put the above effect on the shadow. When the shadow deals damage, it will apply the effect "Strength Drain" to the target of the damage. The effect "Strength Drain" needs to be an effect listed in our custom effects list. The effect looks like this:

  * Strength Drain; STR: -1d4; STACK; RESTL

### Add Effect on Damage Modifiers

* **TDMGADDT: [custom effect]** the TARGET of the attack will add an effect to the TARGET (itself) when damage is done. Consider we have the following magic item. The target of the damages puts the effect "Shield of the 300 Bonus" on itself whenever it takes damage.

  * Shield of the 300; TDMGADDT: Shield of the 300 Bonus
  * Shield of the 300 Bonus; AC: 1; TURNRS; STACK

* **TDMGADDS: [custom effect]**  the TARGET of the attack will add an effect to the SOURCE when damage is done. This is useful for de-buffing the attacker on successful hit. Example would be like a rust monster

  * Rust Monster; TDMGADDS: Rust Metal
  * Rust Metal; DMG: -1; STACK;

* **SDMGADDT: [custom effect]**  the SOURCE of the attack will add an effect to the TARGET when damage is done. The shadow is an example.

  * Strength Drain; STR: -1d4; STACK; RESTL
  * Shadow; SDMGADDT: Strength Drain

* **SDMGADDS: [custom effect]** the SOURCE of the attack will add an effect to the SOURCE (itself) when damage is done.

### Ongoing Damage Modifiers

* **DMGA: (N) [damage type]** Apply damage when the effect is added (N) can be number or dice string
  * AURA: 10 all; Barbarian Raging Storm Desert; DMGA: 2 fire

* **DMGOE: (N) [damage type]** Apply ongoing damage at the end of the actors turn. (N) can be number or dice string
  * Vitriolic Sphere; DMGOE: 5d4 acid

* **SDMGOS: (N) [damage type]** Apply ongoing damage at the start of the actors turn who applied the effect. (N) can be number or dice string

  * Water Elemental Whelm; grappled; restrained; SDMGOS: 2d8+4 bludgeoning
* **SDMGOE: (N) [damage type]** Apply ongoing damage at the end of the actors turn who applied the effect. (N) can be number or dice string

### Ongoing Regeneration Modifiers

* **REGENA (N)** Apply one time regeneration when the effect is added. (N) can be number or dice string

* **REGENE: (N)** Apply regeneration at the end of the actors turn. (N) can be number or dice string

* **SREGENS (N)** Apply regeneration at the start of the actors turn who applied the effect. (N) can be number or dice string

* **SREGENE (N)** Apply regeneration at the end of the actors turn who applied the effect. (N) can be number or dice string

* **TREGENA (N)** Apply one time regeneration to temporary HP when the effect is added. (N) can be number or dice string

* **TREGENS (N)** Apply regeneration to temporary HP at the start of the actors turn. (N) can be number or dice string

* **TREGENE (N)** Apply regeneration to temporary HP at the end of the actors turn. (N) can be number or dice string

* **STREGENS (N)** Apply regeneration to temporary HP at the start of the actors turn who applied the effect. (N) can be number or dice string

* **STREGENE (N)** Apply regeneration to temporary HP at the end of the actors turn who applied the effect. (N) can be number or dice string

## 5E/3.5E/PFRPG

---

### Ongoing Save Modifiers

* **Note:** [SDC] is currently 5E only.  PFRPG and 3.5E will have to replace [SDC] with the save DC

* **SAVES: [ability] [SDC]** Roll save at the start of turn.

  * Web; Restrained; SAVES: DEX [SDC] (C)

* **SSAVES: [ability] [SDC]** Roll save at the start of the actors turn who applied this effect

* **SAVEE: [ability] [SDC]** Roll save at the end of turn.  

  * Frightful Presence; Frightened; SAVEE: WIS 16 (R)
  * Wall of Thorns; SAVEE: DEX [SDC] (H)(C); SAVEDMG: 7d8 slashing

* **SSAVEE: [ability] [SDC]** Roll save at the end of the actors turn who applied this effect

* **SAVEA: [ability] [SDC]** Automatically roll save when the effect is added. Automate NPC debuff effects like Ghoul attack
  * Ghoul Claws; SDMGADDT: GOTU
  * GOTU; Paralyzed; SAVEA: CON 10 (R); SAVEE: CON 10 (R)

* **SAVEDMG: (N) [damage type]** Damage done on a failed ongoing save. (N) can be number or dice string.

* **SAVEADD: [effect]** Add Effect from custom effects list on a failed ongoing save.

* **SAVEADDP: [effect]** Add Effect from custom effects list on a passed ongoing save.

* **SAVEONDMG: [ability] [SDC]** Roll save when the actor takes damage
  * Dominate Person; SAVEONDMG: WIS [SDC] (R)

* **SAVERESTL: [ability] [SDC]** Roll save at on long rest (5E only)

* **(R)** will remove the save effect on a successful save.
* **(D)** will disable the save effect on a successful save.
* **(H)** will deal half damage on a successful ongoing save.
* **(M)** will indicate this is magical so any creature will magic resistance will gain proper advantage on the save.
* **(F)** will invert the roll. SAVEDMG, (R), (D), (H) will be performed on a failed save rather than successful one.
* **(ADV)** will have advantage on this save.
* **(DIS)** will have disadvantage on this save.

## 4E/5E

---

### Damage Reduction

* **DMGR: (N) [damage type(s)][Range]** Reduce the damage taken by the specified damage type(s) by (N).
  * Heavy Armor Master; DMGR: 3 slashing, bludgeoning, piercing, !magic
  * Interception Fighting Style; DMGR: 1d10 [PRF],all
  * Deflict Missles; DMGR: 1d10 [MONK],[DEX],ranged,bludgeoning,piercing

## 4E

---

* **ATKDS** Disable this effect if the source of the effect is attacked

## 5E

---

* **EFFINIT: (N)** Add an effect with initiative number (N)

* **[SDC]** When an effect with [SDC] is applied from a PC/NPC, [SDC] will be replaced with the PC/NPCs spell save DC based off of its spellcasting ability.

* **DC: (N)** If the actor has the effect DC, (N) will be added  to the [SDC] when [SDC] is automatically replaced. (N) can be any number

* **(E)** If the source of the effect drops to zero hit points, then this effect will be removed

### On Attack

* **ATKD** Disable this effect when the actor takes the attack action.
* **ATKA** Enable this effect when the actor takes the attack action.
* **ATKR** Remove this effect when the actor takes the attack action.

### Save vs Condition

Saves against conditions will automatically be granted adv/dis based on the traits of the actor making the saving throw. The parser will match traits with the following verbiage: words ... {advantage,disadvantage} ... words ... {saves,saving throw} ... words ... {condition(s)} ... words

* **ADVCOND: [condition] or [all] *** Grant advantage on a save by this actor against the defined condition
* **DISCOND: [condition] or [all] *** Grant disadvantage on a save by this actor against the defined condition

### No Rest for the Weary

* **NOREST** Actor will not gain the benefit of a short or long rest. Note: Will not prevent the actor from rolling Hit Dice
* **NORESTL** Actor will not gain the benefit of a long rest Note: Will not prevent the actor from rolling Hit Dice

### Concentration

Default off: When on, adding an new spell effect that requires concentration will automatically remove the previous concentration effects if any exist. This can be toggled on/off in the options menu

### Powers Parsing (Experimental)

Will automatically parse Powers (NPC sheets and spells) and automatically setup up some effects using BCE codings. This is defaulted to off in the options menu. Spells that have already been added to a PC must be deleted and re-added to take advantage of this feature.

## Options Menu

---
* **Allow Duplicate Effects** 
  * Default: on
  * 5E - When off, will not allow duplicate effects (same name, duration, actor who applied the effect) on an Actor.
* **Consider Duplicate Duration** 
  * Default: off
  * 5E - When on, considers Concentration duration when determining if previous concentration effects should expire.
  * **Experimental: Autoparse NPC Powers** 
  * Default: off
  * 5E - When on, will autoparse powers and automatically create effects for:
      * DMGOE
      * SDMGOS
      * SDMGOE
      * TURNRS
      * TURNRE
      * STRUNRS
      * STURNRE
      * SAVES
      * SAVEE
* **Restrict Concentration**
  * Default: off
  * 5E - When on, expires any previous spells with concentration (C) when a new concentration spell is cast
* **TempHP Reduction is Damage**
  * Default: on
  * For purposes of determining if something should happen if an actor takes damage. When off, if an actor takes damage that reduces their Temp HP only and NOT their HP (takes wounds), that reduction is not considered damage.

###Changelog BCE Gold
  * Save vs Condition - Saves against conditions will automatically be granted adv/dis based on the traits of the actor making the saving throw.
  * Ongiong Saves (ADV) (DIS) - (ADV)(DIS) can be added to BCE ongoing saves to grant advantage or disadvantage
  * DUR: (N) - Dynamically set the duration of the effect at time of add
  * SAVERESTL - Perform ongoing save on long rest
  * SSAVES, SAVEEE - Perform ongoing save on the source of the effects turn.
  * EEFFINIT: (N) - Set the inititive of the effect on add
  * Replace FGU [] Tags - Tags like [PRF][LVL][CLASS] can now be defined in the NPC sheet effect list as (PRF)(LVL)(CLASS) to process as expected
  * (DE) - Will disable the effect on use
  * SDC - Can be written as [SDC] or (SDC)
  * DMGRR,DMGAT,DMGDT now accept damage and range types as filters
  * (E) - Will remove the effect when the source of the effect drops to 0 HP

