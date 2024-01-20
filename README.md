# HalfSwordTrainerMod
A trainer mod for Half Sword demo v0.3 ([Steam release](https://store.steampowered.com/app/2397300/Half_Sword/)). 

USE AT YOUR OWN RISK.

Compatibility with newer demo versions not guaranteed, and the older demo from `itch.io` won't work.
The mod requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (version 2.5.2 as of now) to work.

The mod is written specifically in Lua, so you can understand and modify its functionality.

## Installation
1) Install [an xInput release of UE4SS 2.5.2 from the official repository](https://github.com/UE4SS-RE/RE-UE4SS/releases/) into the Half Sword demo installation according to UE4SS installation instructions 
([short guide](https://github.com/UE4SS-RE/RE-UE4SS?tab=readme-ov-file#basic-installation) / [full guide](https://docs.ue4ss.com/dev/installation-guide.html)).

Most probably you will copy all the files from the UE4SS release into:
`C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64`,
so the contents of that folder, aside from the actual game files, will now have the following new files and folders:
```
...
\Mods\
...
xinput1_3.dll
UE4SS-settings.ini
UE4SS.dll
...
```

2) Download a release or source package of this `HalfSwordTrainerMod`` repo and unpack it somewhere to take a look. In the next steps you will copy files from inside the folder where you unpacked it.

3) Copy the entire `HalfSwordTrainerMod` folder of the release into the `Mods` folder of your UE4SS installation
(probably into `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Binaries\Win64\Mods`)

4) Copy the entire `LogicMods` folder of the release into the `Content\Paks` folder of your Half Sword demo installation
(probably into `C:\Program Files (x86)\Steam\steamapps\common\Half Sword Demo\HalfSwordUE5\Content\Paks`)

5) Enable the `HalfSwordTrainerMod` and `BPModLoaderMod` in your UE4SS mod loader configuration (`\Mods\mods.txt`).
The new lines in the middle of the file should look like this:
```
...
BPModLoaderMod : 1
...
HalfSwordTrainerMod : 1
...
```
We need **both** of them to be enabled, as `BPModLoaderMod` will load the user interface, which is an Unreal Engine Blueprint type of mod.

6) Enjoy the game and support the developers.

## How to use the mod

The mod adds a HUD on top of the game on the left side of the screen to show you various player stats.
The mod adds a spawn menu on top of the game on the right side of the screen with some drop-down menus and buttons.

The mod adds a few keyboard shortcuts to trigger its functions.

### Keyboard shorcuts of this mod
| Shortcut    | Description |
| ----------- | ----------- |
| U           | Show/hide the **UI** (HUD) of the mod |
| I           | Toggle **Invulnerability** on/off |
| T           | Toggle **Super Strength** on/off |
| L           | Spawn a high-tier **loadout** around the player |
| +           | Increase the current level of enemies |
| -           | Decrease the current level of enemies |
| F1          | Spawn selected Armor |
| F2          | Spawn selected Weapon |
| F3          | Spawn selected NPC |
| F4          | Spawn selected Object |

### Spawning things
You can either spawn a chef's choice loadout around yourself (press `L`), or select what you want in the drop-down menu on the right and spawn each individual item. Use F1-F4 to spawn the selected categories of things if your 

### Other good things
* UE4SS also enables the Unreal Engine console, which can be shown by pressing `F10` or `@`. It is useful to change video settings that are not exposed in Half Sword original UI. When you know which settings you like, you can save then in the game's `.ini` files in 
`%LOCALAPPDATA%\HalfSwordUE5\Saved\Config\Windows\Engine.ini` or other config files in that folder (so most probably in `C:\Users\%USERNAME%\AppData\Local\HalfSwordUE5\Saved\Config\Windows\`)
* UE4SS has a lot of useful functionality for game modders, read [their docs](https://docs.ue4ss.com/) and have fun.


## Know issues and TODOs
* No error handling whatsoever.
* No ability to freeze NPCs yet (use [UUU5](https://opm.fransbouma.com/uuuv5.htm) if you really need that, but be warned that UUU5 freezes only their bottom half, the NPC will still rotate and swing their weapons at you).
* No ability to modify the damage of your weapon or of NPC weapons yet.
* No ability to spawn custom modular weapons yet.
* No ability to un-glitch yourself (weapons stuck in slots, player body joints stuck in unnatural positions, etc.). Invulnerability helps, though.


## FAQ
### What to do?
Support the developers of Half Sword (https://halfswordgames.com/). 

They have a Kickstarter campaign, currently at https://www.kickstarter.com/projects/halfsword/half-sword-gauntlet

### Game hangs up or freezes or does not respond?
Press `Win + R` and execute the following command line:
```
taskkill /f /im HalfSwordUE5-Win64-Shipping.exe
```
That will kill the game, even if you cannot close it otherwise. In the worst case, reboot.

### UE4SS does not load?
Make sure you can install UE4SS and make it work (confirm that it operates, check its logs, open its GUI console).
* If UE4SS does not work, this mod cannot run at all. It absolutely needs a correct UE4SS installation before you install this mod.

### UE4SS crashes the game?
TBD. Try disabling mods one by one, until you find out what triggers the crash.

### Mod does not load?
Make sure UE4SS loads and observe its logs. It should mention `HalfSwordTrainerMod`. 
* If it does not, check that you have the mod files in the right places as explained above.
* If it does, but the mod does not show UI or does not react to the keyboard shortcuts, check the logs for errors related to `HalfSwordTrainerMod`.

### Mod crashes the game?
If you suspect the fault is in the logic of this mod, you can try to disable or comment out the last suspicious thing that you used before the crash.

### Mod works, but does not do what I expect?
File an issue here, at https://github.com/massclown/HalfSwordTrainerMod/issues

## Acknowledgements
* Half Sword developers, https://halfswordgames.com/
* UE4SS developers, https://github.com/UE4SS-RE/RE-UE4SS
* Bjorn Swenson, developer of `maf`, https://github.com/bjornbytes/maf which is used for vector rotation here.
* TheLich from nexusmods for caching code
