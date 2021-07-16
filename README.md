# Better Combat Effects

FantasyGrounds CoreRPG extension

Better Combat Effects extension allows for fine tuning of when effects are enabled, disabled, removed, and added.

## Installation

Download [BetterCombatEffects.zip](https://github.com/rhagelstrom/BetterCombatEffects/raw/main/BetterCombatEffects.zip) Unzip and place the .ext in the extensions subfolder of the Fantasy Grounds data folder and the .mod in the modules subfolder.

## CoreRPG

---

### Turn Modifiers

* **TURNAS** will cause an effect to ACTIVIATE on the START of the PC/NPC turn. Using TURNAS along with DMGDT allows items such as the Cloak of Displacement or a Displacer Beast's Displacement to function properly.

  * Cloak of Displacement; GRANTDISATK; TURNAS; DMGDT

* **TURNDS** will cause an effect to DEACTIVIATE on the START of the PC/NPC turn.

* **TURNRS** will cause the effect to be REMOVED on the START of the PC/NPC turn if current duration is 1. 

  * Dodge; TURNRS

* **TURNAE** will cause an effect to ACTIVIATE on the END of the PC/NPC turn.

* **TURNDE** will cause an effect to DEACTIVIATE on the END of the PC/NPC turn.

* **TURNRE** will cause the effect to be REMOVED at the END of the PC/NPC turn if current duration is 1. This is useful for conditions like poison to be removed but do not require a saving throw.

  * Poisoned; Poisoned; TURNRE

* **STURNRS** will cause the effect to be REMOVED on the START of the source of the effects turn if current duration is 1. This is useful for conditions with the text "until the start of your next turn"

* **STURNRE** will cause the effect to be REMOVED on the END of the source of the effects turn if current duration is 1. This is useful for conditions with the text "until the end of your turn"

  * Stunning Strike; Stunned; STURNRE

## 5E/4E/3.5E/Pathfinder 1E

---

### Rest Tags

**RESTL**, for long rest and **RESTS** for short rest. These tags will REMOVE an effect on short rest or long rest. Effects with RESTS will also be removed on long rest.

* Exhaustion; EXHAUSTION: 1; RESTL
* True Seeing; VISION: 120 truesight; RESTS
* Mage Armor; AC: 3; RESTL

### Automatic Ability Score

Items that adjust an ability score to a number. Item of Giant Strength, Headband of Intellect, are automatically calculated when added to the PC/NPC on the combat tracker if they use the **-X** format. The effect will need to be deleted the effect and re-added it on an ASI to have the value recalculated.

* Belt of Frost Giant Strength; STR: 19-X;
* Headband of Intellect; INT: 19-X;

Additionally, effects that use ability score modifiers in the format [ ABILITYSCORE ] are handled automatically. The score between [ ] is replaced with the correct modifier

* Lifedrinker;DMG:[CHA], melee

### STACK

Multiple identical effects are now ignored. If a PC/NPC is poisoned, it won't be poisoned again. This however can be overridden with the STACK tag for effects that need to stack such as a shadow's Strength Drain. The ignore duplicates can be disabled in the options menu.

* Strength Drain; STR: -1d4; STACK; RESTL

### Dice in Effect

Adding effect with a dice string automatically rolls the dice when the effect is applied. The Shadow's Strength Drain can now be automated. Only die that modify ability scores (STR,DEX,CON,WIS,INT,CHA) will be rolled

### Damage Modifiers

* **DMGAT** will cause an effect to ACTIVIATE when the PC/NPC takes damage.

* **DMGDT** will cause an effect to DEACTIVIATE when the PC/NPC takes damage. Allows items like Cloak of Displacement to function properly.

  * Cloak of Displacement; GRANTDISATK; TURNAS; DMGDT

* **DMGRT** The effect will be REMOVED from the PC/NPC if they take damage. This is useful for turn undead or sleep

  * Turn Undead; Turned; DMGRT
  * Sleep; Unconscious; DMGRT

### Add Effect on Damage Modifiers

Effects can be automatically added to the source or the target on the damage by either the source of the damage or the target of the damage. For this to work we need two different effects.  Example:

  * Shadow; SDMGADDT: Strength Drain

The Shadow has strength drain so we put the above effect on the shadow. When the shadow deals damage, it will apply the effect "Strength Drain" to the target of the damage. The effect "Strength Drain" needs to be an effect listed in our custom effects list. The effect looks like this:

  * Strength Drain; STR: -1d4; STACK; RESTL

### Add Effect on Damage Modifiers

* **TDMGADDT** the TARGET of the attack will add an effect to the TARGET (itself) when damage is done. Consider we have the following magic item. The target of the damages puts the effect "Shield of the 300 Bonus" on itself whenever it takes damage.

  * Shield of the 300; TDMGADDT: Shield of the 300 Bonus
  * Shield of the 300 Bonus; AC: 1; TURNRS; STACK

* **TDMGADDS** the TARGET of the attack will add an effect to the SOURCE when damage is done. This is useful for de-buffing the attacker on successful hit. Example would be like a rust monster

  * Rust Monster; TDMGADDS: Rust Metal
  * Rust Metal; DMG: -1; STACK;

* **SDMGADDT** the SOURCE of the attack will add an effect to the TARGET when damage is done. The shadow is an example.

  * Strength Drain; STR: -1d4; STACK; RESTL
  * Shadow; SDMGADDT: Strength Drain

* **SDMGADDS** the SOURCE of the attack will add an effect to the SOURCE (itself) when damage is done.

### Ongoing Damage Modifiers

* **DMGOE (N) [damage type]** Apply ongoing damage at the end of the actors turn. (N) can be number or dice string

* **SDMGOS (N) [damage type]** Apply ongoing damage at the start of the actors turn who applied the effect. (N) can be number or dice string

* **SDMGOE (N) [damage type]** Apply ongoing damage at the end of the actors turn who applied the effect. (N) can be number or dice string

## 5E/3.5E/Pathfinder 1E

---

### Ongoing Save Modifiers

* **SAVES: [ability] [SDC]** Roll save at the start of turn.

  * Web; Restrained; SAVES: DEX [SDC] (C)

* **SAVEE: [ability] [SDC]** Roll save at the end of turn.  

  * Frightful Presence; Frightened; SAVEE: WIS 16 (R)
  * Wall of Thorns; SAVEE: DEX [SDC] (H)(C); SAVEDMG: 7d8 slashing

* **SAVEA: [ability] [SDC]** Automaticlly roll save when the effect is added

* **SAVEDMG: (N) [damage type]** Damage done on a failed ongoing save. (N) can be number or dice string.

* **[SDC]** When an effect with [SDC] is applied from a PC, [SDC] will be replaced with the PCs spell save DC based off of its spellcasting ability. 

* **(R)** (R) will remove the save effect on a successful save.
* **(D)** (D) will disable the save effect on a successful save.
* **(H)** (H) will deal half damage on a successful ongoiong save.
* **(M)** (M) will indicate this is magical so any creature will magic resistance will gain proper advantage on the save.

## 5E

---

### Concentration

Default off: When on, adding an new spell effect that requires concentration will automatically remove the previous concentration effects if any exist. This can be toggled on/off in the options menu
