# CubarmySpire
Cubarmy Spire game (Bachelor's project)

Simple “rogue like” game where player starts a dungeon and runs through levels/depth where he has a small army of warriors which automatically fights enemy army. After each level he can choose one of few boosts which will empower or increase user’s army for this exact “run”. Enemies are generated automatically on each level and have randomized power increase too (faster than user). After losing on any level the user gets some resources.
In the menu user can not only just start game (“run”) but go to inventory or shop. In the shop user can buy new units, items or upgrades for gold. In inventory he can equip items (user is considered a general and his equipped items will empower his units), manage units and open craft menu. In the craft menu there will be recipes for items which are crafted from resources. Units should be managed because they will have different levels and there will be a limit for an army.
It is planned that users will have to register and login in order to track and save progress. “Guest” option will also exist but will not save progress.

### Entities

- Game – manage GUI, manage “runs”, works with User
- User – has items, resources, gold, army, current powerups
- Army – units collection and management
- Unit – stats and type, powerup amplification, fight logic
- Powerup – collection of all, collection of current, logic of each type
- Item – type (equipment slot), boost/stat increase, recipe


### Screens/windows

- Main menu – start “run”, inventory, shop, logout
- Inventory – user equipment, units collection, items in inventory, crafting
- Crafting – recipes to craft
- Shop – unit row, equipment row, resources row
- Battle (started “run”) – units on arena, retreat, boost select (after no enemy remains), “run” statistics (if user lost)
