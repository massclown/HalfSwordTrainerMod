# Half Sword Trainer Mod

A trainer mod for Half Sword demo v0.3 ([Steam release](https://store.steampowered.com/app/2397300/Half_Sword/)). 

It gives you Invulnerability, Super Strength, configurable level of enemy NPCs, jumping, shooting, and the ability to spawn armour, weapons, NPCs and objects (and despawn them if you made a mistake), setting game speed and more. The mod also has a detailed HUD with player stats. 

USE AT YOUR OWN RISK.

Compatibility with newer demo versions not guaranteed, and the older demo from `itch.io` won't work.
The mod requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (version 2.5.2 or 3.x.x as of now) to work.

The mod is written in Lua, so you can understand and modify its functionality.

# Showcase

[![YouTube video of Half Sword Trainer Mod](https://img.youtube.com/vi/DMWCSHe60dA/hqdefault.jpg)](https://www.youtube.com/watch?v=DMWCSHe60dA)

# Installation (easy mode)

# One-click automatic installer at https://github.com/massclown/HalfSwordModInstaller/releases/latest/download/HalfSwordModInstaller.exe

# Automatic installer documentation at https://github.com/massclown/HalfSwordModInstaller

# Installation (hard mode)
<details>
  <summary>Click to see the full installation instructions (hard mode)</summary>

You probably want the easy mode above. If you really really want to install everything manually, read below.

## Video tutorial: https://www.youtube.com/watch?v=4gSp87ET6x4

## Screenshots with the steps: https://imgur.com/a/3RFOQiS

You need to choose which UE4SS version you want. For some people, UE4SS 2.5.2 is more stable, for some, UE4SS 3.x.x is more stable.

For me, UE4SS 3.x.x is currently more stable.

## 1a. (only if using UE4SS 2.5.2) Install UE4SS 2.5.2 into the game folder 

Install [an xInput release of UE4SS 2.5.2 from the official repository (UE4SS_Xinput_v2.5.2.zip)](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v2.5.2) into the Half Sword demo installation folders according to the UE4SS installation instructions 
([short guide](https://github.com/UE4SS-RE/RE-UE4SS?tab=readme-ov-file#basic-installation) / [full guide](https://docs.ue4ss.com/dev/installation-guide.html)). Basically you will need to unzip that archive and copy the files into the right place. Read the guides for help.

Most probably you will copy all the files from the UE4SS release into:
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64`,
so the contents of that folder, aside from the actual game files, will now have the following **new** files and folders of UE4SS:
```
...
\Mods\
...
xinput1_3.dll
UE4SS-settings.ini
...
```

## 1b. (only if using UE4SS 3.x.x) Install UE4SS 3.x.x into the game folder 

Install [a release of UE4SS 3.x.x from the official repository (UE4SS_v3.x.x.zip)](https://github.com/UE4SS-RE/RE-UE4SS/releases/) into the Half Sword demo installation folders according to the UE4SS installation instructions 
([short guide](https://github.com/UE4SS-RE/RE-UE4SS?tab=readme-ov-file#basic-installation) / [full guide](https://docs.ue4ss.com/dev/installation-guide.html)). Basically you will need to unzip that archive and copy the files into the right place. Read the guides for help.

Most probably you will copy all the files from the UE4SS 3.x.x release into:
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64`,
so the contents of that folder, aside from the actual game files, will now have the following **new** files and folders of UE4SS:
```
...
\Mods\
...
dwmapi.dll
UE4SS-settings.ini
UE4SS.dll
...
```

> **WARNING!** If upgrading from UE4SS 2.5.2 to UE4SS 3.x.x, first delete the old `xinput1_3.dll`.

## 2. Download this mod

Download either a release, or a source package of this `HalfSwordTrainerMod` repo and unpack it somewhere to take a look. 
* If you want a more stable build, take a named version [from the releases](https://github.com/massclown/HalfSwordTrainerMod/releases)
* If you want a fresh development one, click the green "<>Code" button in the top-right of the page and select "Download ZIP".

In the next steps you will copy some folders from inside the folder where you unpacked it into the game folders.

When you unzip the archive, it is going to look like this:
```
\BPModLoaderMod\       --> (!only for UE4SS 3.x.x!) this needs to be copied into the `Mods` folder of your UE4SS installation
\HalfSwordTrainerMod\  --> this needs to be copied into the `Mods` folder of your UE4SS installation
\images\               
\LogicMods\            --> this needs to be copied into the `Content\Paks` folder of your Half Sword demo installation
LICENSE
README.md
```

> **WARNING!** To use this mod with UE4SS 3.x.x, you need to patch one standard mod inside the installed UE4SS `Mods` folder, namely, `BPModLoaderMod`.
> 
> It is included in the release of this mod, it is the `BPModLoaderMod` folder.
> As stated above, copy its `BPModLoaderMod` over the **installed** UE4SS 3.x.x `Mods\BPModLoaderMod`. 
> 
> If you are on UE4SS 2.5.2, you don't need to copy `BPModLoaderMod`


## 3. Copy the code of this mod

Copy the entire `HalfSwordTrainerMod` folder of the release into the `Mods` folder of your UE4SS installation
(probably into `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64\Mods`)

## 4. Copy the Blueprints of this mod

Copy the entire `LogicMods` folder of the release into the `Content\Paks` folder of your Half Sword demo installation
(probably into `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Content\Paks`)

## 5. Enable the mod

Enable the `HalfSwordTrainerMod` and `BPModLoaderMod` in your UE4SS mod loader configuration (`\Mods\mods.txt`).
The new two lines in the middle of the file should look like this (better to copy-paste them to avoid typos, but don't copy the "...", of course):
```
...
BPModLoaderMod : 1
...
HalfSwordTrainerMod : 1
...
```
We need **both** of them to be enabled, as `BPModLoaderMod` will load the user interface, which is an Unreal Engine Blueprint type of mod.

## 6. Enjoy the game and support the developers.

# Updating or installing a new release

* You can copy files from the new release of the mod on top of the old one. I do my best to not make old files cause any problems in the new version.
* If something weird is still happening:
    * delete the old `HalfSwordTrainerMod` folder in the `Mods` folder of your UE4SS installation
    (probably in your `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64\Mods`)
    and then copy the new one from the new release.
    * delete the old `LogicMods` folder in the `Content\Paks` folder of your Half Sword demo installation
    (probably in your `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Content\Paks`)
    and then copy the new one from the new release.
    * the configuration in `\Mods\mods.txt` does not need to be changed.

# Uninstalling the mod files

Delete the files that you copied as described above, or just reinstall the entire Half Sword game entirely (it will wipe all the folders where the installed mod is located). 

# Temporarily disabling the mod

* You can disable the mods that UE4SS loads, including this mod, in `\Mods\mods.txt`.
    * Disable or enable **both** `HalfSwordTrainerMod` and `BPModLoaderMod` in `\Mods\mods.txt`, otherwise you will still see the broken UI of the mod.
* Alternatively, you can rename `xinput1_3.dll` (or `UE4SS.dll` if you are on UE4SS 3.x.x) to something else, say, `xinput1_3.dll.backup` to completely disable UE4SS and all the mods it loads.

</details>

# Keyboard shortcuts of this mod

| Shortcut           | Description        |
| ------------------ | ------------------ |
| `U`                | Show/hide the UI (HUD) of the mod |
| `Alt + U`          | Skip the death screen (only when dead) |
| `Ctrl + J`         | Try to resurrect the player (only when dead) |
| `.`                | Show/hide the crosshair |
| `I`                | Toggle Invulnerability on/off |
| `T`                | Toggle Super Strength on/off |
| `L`                | Spawn a loadout around the player |
| `+`                | Increase the current level of enemies |
| `-`                | Decrease the current level of enemies |
| `F1`               | Spawn selected Armor |
| `F2`               | Spawn selected Weapon |
| `F3`               | Spawn selected NPC |
| `F4`               | Spawn selected Object |
| `F5`               | Undo last spawn (can be repeated) |
| `F6`               | Despawn all NPCs |
| `B`                | Spawn the Boss Arena fence around the player's location (only the fence) |
| `K`                | Kill all NPCs currently on the map |
| `Z`                | Freeze or unfreeze all NPCs currently on the map |
| `M`                | Toggle Slow Motion mode |
| `[`                | Decrease game speed for Slow Motion |
| `]`                | Increase game speed for Slow Motion |
| `Space`            | Jump (at your own risk) |
| Mouse Wheel Click  | Shoot projectile |
| `Tab`              | Change projectile to the next one |
| `Shift + Tab`      | Change projectile to the previous one |
| `Ctrl + End`       | Possess the NPC closest to player |
| `Ctrl + Home`      | Possess the original player character |
| NumPad 4/6/8/2     | Dash Left/Right/Forward/Backward |
| `*` on NumPad      | Pause/Unpause the game. Use that in Photo Mode to have free cam in battle |
| `+` on NumPad      | Switch player team to the next one |
| `-` on NumPad      | Switch player team to the previous one |
| `Delete`           | Despawn the object in the center of screen (first person view is better) |
| `Ctrl + F`         | Command all NPCs in the same team as player to go to the player location |


# How does the mod look on screen

![Alt text](images/hud_v0.9_2K.jpg?raw=true "Screenshot of mod UI v0.9")

# How to use the mod

The mod has a custom UI that can be hidden when needed, and can also hide the crosshair (cursor).

The mod adds a HUD on top of the game on the left side of the screen to show you various player stats.

* The body figure in the bottom left corner is the health of the body parts.

The mod adds a spawn menu on top of the game on the right side of the screen with some drop-down menus and buttons.

The mod also adds a few keyboard shortcuts to trigger its functions.

## Changing difficulty

* Increasing and decreasing the level with `+` and `-` will affect the level of the auto-spawned NPCs.

* "SuperStrength" makes your attacks with any weapon a bit better.

* Invulnerability does not need much explanation. Regeneration is also applied when Invulnerable.

> Note that the game itself (not the mod!) makes your player invulnerable for a first few seconds during spawn (maybe to avoid dying due to physics of the game?), and then removes invulnerability.

## Changing teams

Press `+` or `-` on NumPad to cycle the player between available teams (0, 1, 2).

You can select any team for the player or for NPCs you spawn.

* By default, the player is in **Team 0**. 
* **Team 0** is **"deathmatch"**: every NPC in Team 0 will be hostile towards each other and the player, even if the player is in Team 0. The player is in Team 0 by default.
* **Team 1** does not seem to be used by the game currently (but we can use it for the player and NPC we spawn). Team 1 does not attack Team 1.
* **Team 2** is all the **auto-spawned NPCs and bosses**. Move your player to this team if you don't want to be attacked by what the game auto-spawns against you. Team 2 does not attack Team 2.

The above can also be summarized as the following: the game treats everybody in Team 0 as "deathmatch", and Team 1 vs Team 2 is classic "team deathmatch".

## Spawning things

* You can either spawn a complete "chef's choice" loadout around yourself (press `L`),

* or, first, **pause** the game, select what you want in the drop-down menu on the right, and spawn each individual item. 

Use the buttons on screen to spawn items while the game is paused, or use `F1` - `F4` to spawn the selected things in each category (armor, weapons, NPCs, objects) when the game is running.

Player's viewpoint direction is used to place the spawned object in the world. NPCs are placed a bit further than items.

When spawning NPCs, you can select which team to spawn them in. By default, the NPCs spawned from the mod are in Team 0 (deathmatch, everybody hostile to everybody including the player)

The on-screen spawn menu also has a custom weapon size slider. With the checkboxes X/Y/Z, select which coordinate axes you want to apply the scale to. Z is the top-bottom axis, X is the left-right and Y is the front-back. Scaling proportionately gives best results for comedic effect, but sometimes weapons become too thick to grab for the player. You also can toggle the "Blade scaling?" checkbox to apply the scaling factor only to the blade of the weapon (helps with grip problems, but may affect the balance of the weapon). Blade scaling only works for swords.

> The names of objects in the on-screen spawn menu have been shortened for better readability.

### Loadout configuration

To modify the pre-configured loadout that is spawnable with `L` button, edit the `custom_loadout.txt` text file in the `data` subfolder of the mod:
```
Mods\HalfSwordTrainerMod\data\custom_loadout.txt
```
It contains the list of Unreal Engine class names that will be loaded. Look around in the files in the `\data\` folder for examples. Note that these are full class names, not the shortened ones on-screen.
A default loadout is also hardcoded in the mod itself, in case the custom loadout file gets deleted.

You can also prefix the class names in custom loadout text file with the scaling factor, in round parentheses:
```
(5.0)/Game/Assets/Weapons/Blueprints/Built_Weapons/Buckler4.Buckler4_C
(1.0,5.0,1.0)/Game/Assets/Weapons/Blueprints/Built_Weapons/Buckler4.Buckler4_C
```
A single number in parentheses means equal scaling in all directions, three numbers is independent scaling in X,Y,Z order.
The scale is optional, default scale is 1.0 == no scale.

Starting the line with the `[BladeOnly]` tag means that only the blade of the weapon will be scaled, a behavior similar to the "Blade scaling?" flag in the mod UI:
```
[BladeOnly](2.0)/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword.ModularWeaponBP_BastardSword_C
```

## Despawning things

Use `F5` or the on-screen button to undo the last spawned thing. It can be used repeatedly to undo many things.

> If you want to find a particular random variant of some item, select it in the menu, then go unpause the game, and repeatedly press the corresponding `F1` - `F4` button, and if you don't like it, press `F5` to undo.

You can use the `Delete` key to also despawn almost anything under the center point of the screen. 
First person mode works better for that. In the default third person view, the displayed crosshair is not in the center of the screen, so it is hard to find what you want to despawn. Use first-person view!

> You can despawn weapons right from the NPC's hands or belts if you aim well enough!

## Killing NPCs

Use `K` or the on-screen button to kill all the NPCs that were spawned by the game or by you. May crash the game sometimes, but should work better now.

## Freezing / unfreezing NPCs

Use `Z` the on-screen button to freeze/unfreeze all the NPCs that were spawned by the game or by you. Will not prevent new ones from spawning, or affect these new ones (until you try freezing/unfreezing them again).

## Slow motion

Use `M` to toggle Slow Motion mode, and `[` and `]` to decrease and increase slow motion speed. 

* If Slow Motion is on, then the speed change will be applied immediately.

* Otherwise, selected speed will be applied after Slow Motion is enabled

It may crash the game if you change the game speed too often or in the middle of a fight.

## Jumping

Use `Space` to jump. There is a cooldown of 1 second to prevent flying into the sky and crashing down. Sometimes you may be able to jump higher, use at your own risk.

Jump does not work when the player is down on the ground.

Jump does not work well when changing the game speed.

## Shooting projectiles

This is not a "true" throwing of objects, but more like shooting or launching them for maximum damage.

Use mouse wheel (click) to shoot a projectile, and `Tab` to change to next projectile type, `Shift + Tab` for the previous projectile type.

Shooting is more accurate in first person view.

The projectiles are currently hardcoded in the mod to account for scaling, launch position and speed adjustments:

* Your currently selected weapon from the Spawn menu (including current scale!)
* 0.5x scaled spear 
* 0.5x scaled pitchfork
* dagger
* small axe
* mallet
* stool
* buckler
* breakable barrel
* bench
* table
* Your currently selected NPC from the Spawn menu (including current NPC team!)

> **WARNING!** Launching NPCs may lead to a crash soon.

> **WARNING!** Launching large objects like full-size scythes, spears, greatswords, polearms, etc. can damage the player!

> **WARNING!** Beware of ricochets!

## Skip the death screen

Press `Alt + U` to skip the death screen and unpause the game. You can still control the camera and enjoy the views, and apply the mod functions to the NPCs if needed.

## Resurrect the player

Press `Ctrl + J` to attempt to resurrect the player (after you removed the death screen, of course). 

Having exploded head or being decapitated still appears to be fatal in the current version, as are some other injuries.

Resurrection may be repeated as needed.

> **NOTE:** You may need to activate Invulnerability before or after that, as some injuries will drain the health / tonus / other stats and kill the player again.

> **NOTE:** Resurrection is known to break some of the mod's functionality, use with caution.

> **WARNING!** NPCs may continue attacking the dead player, so be prepared.

## Possessing NPCs

You can take control of other NPCs by "possessing" them

Press `Ctrl + End` to possess the closest NPC to the currently possessed one, and `Ctrl + Home` to jump back to the original player.

> **NOTE:** Sometimes the NPC you possess may be bugged. 

## Pause/unpause the game to get free camera

Enter Photo Mode (press `C`), then enter free camera (press `F`), then press `*` on NumPad to unpause the game.

This allows you to use all filters and effects of the photo mode with the free camera while the battle is ongoing.

Together with player and NPC team selection and freezing NPCs on spawn or with a button (`Z`), you can set up team battles in advance.

## Commanding friendly NPCs

Press `Ctrl + F` to command all NPCs of the same team to go to the player location. It often does not work, e.g. if the NPCs are busy with something (like looking at a half-dead enemy NPC from another team).

## Other good things

* UE4SS also enables the Unreal Engine console, which can be shown by pressing `F10` or `@`. It is useful to change video settings that are not exposed in Half Sword original UI. 
    * When you know which settings you like, you can edit them permanently in the game's `.ini` files in 
`%LOCALAPPDATA%\HalfSwordUE5\Saved\Config\Windows\Engine.ini` or other config files in that folder (so most probably in `C:\Users\%USERNAME%\AppData\Local\HalfSwordUE5\Saved\Config\Windows\`)
    * Some examples of the settings you might want to change in those files (or in the console, on the fly) are, for `Engine.ini`:
    ```
    [SystemSettings]
    r.fog=0
    r.atmosphere=0
    r.AntiAliasingMethod=1
    ```
* UE4SS has a lot of useful functionality for game modders, read [their docs](https://docs.ue4ss.com/) and have fun.
    * You can open the UE4SS's graphical console, find Unreal Engine objects, and modify their attributes (like the score, for example).


# Know issues and TODOs

* No error handling whatsoever. Use at your own risk. **It will crash the game at some point!** Don't spawn too many things, or more than 10-15 NPCs, etc.

* The mod's keybinds don't work if you keep holding down the game standard keybinds (like when running with A/W/S/D). Some keybinds have been modified to work while holding `Shift` or `Ctrl`, but may be unstable.

* Auto-spawned NPCs and boss fights will keep spawning. 

* The custom loadout is spawned in the map, not on the player.

* Freezing only freezes the bottom part of the NPCs, they can still use weapons on the player.

* No ability to remove armor from the player.

* No ability to modify the damage of your weapon or of NPC weapons yet.

* No ability to spawn custom modular weapons yet (we spawn a random version).

* No ability to un-glitch yourself (weapons stuck in slots, player body joints stuck in unnatural positions, etc.). Invulnerability helps, though.

* No ability to fly (for jumping see above).

* Possessing or un-possessing NPCs may leave them bugged.

# FAQ

## What to do?

Support the developers of Half Sword (https://halfswordgames.com/). 

They have a Kickstarter campaign, currently at https://www.kickstarter.com/projects/halfsword/half-sword-gauntlet

## Game hangs up or freezes or does not respond?
Press `Win + R` and execute the following command line:
```
taskkill /f /im HalfSwordUE5-Win64-Shipping.exe
```
This will kill the game, even if you cannot close it otherwise. In the worst case, reboot.

## UE4SS does not load?
Make sure you can install UE4SS and make it work (confirm that it operates, check its logs, open its GUI console).
* If UE4SS does not work, this mod cannot run at all. It absolutely needs a correct UE4SS installation before you install this mod.

## UE4SS crashes the game?
TBD. Try disabling mods one by one, until you find out what triggers the crash.

Also, try setting the following values in `UE4SS-settings.ini`, in the folder where you installed UE4SS:

```
[EngineVersionOverride]
MajorVersion = 5
MinorVersion = 1
```

If the game is unplayable at all, disable UE4SS or reinstall the game (whatever is faster/easier).

## Mod does not load?
Make sure UE4SS loads and observe its logs. It should mention `HalfSwordTrainerMod`. 
* If it does not, check that you have the mod files in the right places as explained above.
* If it does, but the mod does not show UI or does not react to the keyboard shortcuts, check the logs for errors related to `HalfSwordTrainerMod`.

## I see the HUD/UI of the mod, but number values are zero, UI buttons don't work and drop-down menus are empty

> If you are on UE4SS 3.x.x, check that you have patched `BPModLoaderMod` as described in the installation instructions above.

That means that `BPModLoaderMod` has worked correctly and loaded our Blueprint mod (that is the UI of the mod), 
but the actual Lua mod named `HalfSwordTrainerMod` can't work due to one of the possible reasons: 
* either it is missing in the `Mods` folder entirely, 
* or it is not copied in the correct folder structure (say, the Lua files of the mod must be in `Mods\HalfSwordTrainerMod\scripts\`), 
* or it is not enabled in the `Mods\mods.txt`, 
* or the mod cannot start due to some error. 

Check which of these things might have happened on your system, and also look inside `UE4SS.log` and see if there are any error lines looking like `[HalfSwordTrainerMod] [ERROR]`.

If you see:
```
HSTM UI version mismatch: mod version 0.x, HUD version 0.y
```
then you have copied different parts of the mod from different versions. Re-install the mod from the version you want as described above.

## I see the HUD/UI of the mod, the numbers are correct and the UI buttons and drop-down menus work, but the keyboard hotkeys don't work

Unfortunately, this happens sometimes, usually a reboot helps.

## I don't see the HUD/UI of the mod on screen, but some hotkeys still work

That means that the `BPModLoaderMod` did not work or could not find the Blueprint mod, and therefore did not load our Blueprint mod that is the UI, 
while Lua mod named `HalfSwordTrainerMod` succeeded. 

`BPModLoaderMod` probably couldn't work due to one of the possible reasons: 
* either it is missing in the `Mods` folder entirely, probably with all other folders out of the UE4SS package
* or it is not enabled in the `Mods\mods.txt`, 
* or the `LogicMods` folder is missing from `\Half Sword Demo\HalfSwordUE5\Content\Paks`, or its contents are wrong (e.g. wrong version of Blueprints in `LogicMods`, see above),
* or the mod cannot start due to some error. 

Check which of these things might have happened on your system, and also look inside `UE4SS.log` and see if there are any error lines saying something suspicious right after the line:
```
[2024-01-21 12:06:20] Starting Lua mod 'BPModLoaderMod'
```

## Mod crashes the game?

If you suspect the fault is in the logic of this mod, you can try to disable or comment out the last suspicious thing that you used before the crash.

## Mod works, but does not do what I expect?

File an issue here, at https://github.com/massclown/HalfSwordTrainerMod/issues

## Any other problem with this mod, or a feature request?

File an issue here, at https://github.com/massclown/HalfSwordTrainerMod/issues

# License

Distributed under the MIT License. See `LICENSE` file for more information.

# Acknowledgements

* Half Sword developers, https://halfswordgames.com/
* UE4SS developers, https://github.com/UE4SS-RE/RE-UE4SS
* Bjorn Swenson, developer of `maf`, https://github.com/bjornbytes/maf which is used for vector rotation here.
* TheLich from NexusMods for caching code
* @glassoflimesoda from Half Sword Discord for the screenshot install tutorial at https://imgur.com/a/3RFOQiS
* The community members of the Half Sword Discord for inspiration and bug reports.

