# Macro Action Bar

A World of Warcraft forever addon that allow players to easily configure macro's straight from the spellbook.

## Configuring your class

Each class has its own file in `src/Config/` (for example `src/Config/Warlock.lua`). It sets the page's sections,
which spells offer mouseover or cursor casting, and your own custom macros. `src/Config/Config.lua` explains
each list. Edit your class's file, then type `/reload` in game.

Spells that aren't in any section appear under "Unsorted" at the end of the page.