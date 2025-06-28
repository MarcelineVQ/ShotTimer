Shot Timer 1.4
===
[SuperWoW](https://github.com/balakethelock/SuperWoW/) required  
___

Includes:
* Ranged 'swing timer'
* Indictor of safe period to Steady Shot
* Indictor of Multi-Shot cooldown
* Macro functions

Use `/shottimer` for in-game options.

Will not include an Aimed Shot indicator, aimed shot is a 3.5 second cast on TurtleWoW due to how vmangos is coded, the safe time to use it is simply **as soon as possible** after Auto Shot fires and only if your weapon is 3.2 speed or better and you don't have Steady Shot, or 3.4 or better if you do have Steady Shot.  
___
Macro api:
---
* `RangedSwingTime` global variable giving the time left before the next Auto Shot
* Non-clipping shot casts via `/run ST_SafeShot(shot)` accepting "aimed", "steady", "multi"
* * `/shottimer aimed` `/shottimer steady` `/shottimer multi`
* Auto Shot auto-attack via: `/run ST_AutoShot()` or `/shottimer auto`
* Feign Death when between dot ticks / autoshots: `/run ST_SafeFD()` or `/shottimer fd`
* * This attempts to account for if you've fired a shot as well since a shot in flight will re-engage you.
* * Automatically recalls pet as it is REQUIRED to succeed at trinket swaps.
* Safer pet attack: `/run ST_SafePetAttack()` or `/shottimer petattack`
* * Only sends pet if you and your target are in combat.
* * The intent for this is to increase pet uptime mid-combat, you should still manually send a pet in via keybinds.
* Determine if it's safe for pet to act: `/run if ST_PetMayAttack() then ST_SafePetAttack() end`
* * Used in the above.

Macro examples:
---
Autoshot+shots with a priority order:
```
/shottimer auto
/shottimer aimed
/shottimer steady
/shottimer multi
```
Autoshot+petattack, using Bite if enough Focus has pooled:
```
/run if ST_PetMayAttack() and UnitMana("pet") >= 70 then CastSpellByName("Bite") end
/shottimer petattack
/shottimer auto
```

___
* Made by and for Weird Vibes of TurtleWoW