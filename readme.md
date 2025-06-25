Shot Timer 1.2
===
[SuperWoW](https://github.com/balakethelock/SuperWoW/) required  
___

`/shottimer` for options

Includes:
* Ranged 'swing timer'
* Indictor of safe period to Steady Shot
* Indictor of Multi-Shot cooldown
* Macro commands and functions:
* * Global variable `RangedSwingTime` giving the time left before the next Auto Shot
* * Non-clipping shot casts via `/run ST_SafeShot(shot)` accepting "aimed", "steady", "multi"
* * * `/shottimer aimed` `/shottimer steady` `/shottimer multi`
* * Auto Shot auto-attack via: `/run ST_AutoShot()`
* * * `/shottimer auto`

Examle shot macro with autoshot and a priority order:
```
/shottimer auto
/shottimer aimed
/shottimer steady
/shottimer multi
```

Will not include an Aimed Shot indicator, aimed shot is a 3.5 second cast on TurtleWoW due to how vmangos is coded, the safe time to use it is simply **as soon as possible** after Auto Shot fires and only if your weapon is 3.2 speed or better.  

___
* Made by and for Weird Vibes of TurtleWoW