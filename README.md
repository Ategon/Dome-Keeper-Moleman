# Dome Keeper Moleman Mod
A mod that adds a new keeper to the game, the Moleman!

This mod is currently in beta testing while we wait for the game to get official mod support. To chat about the mod, report bugs, or give feedback head over to Ategon's development discord at  https://discord.gg/HNwTAW7

# Contributors
- Ategon - Art, Code, Music, Initial Design
- Leif - Code

# How to use the Mod
(Note as theres no official mod support there will be a bunch of steps. It should be as easy as choosing the mod from the steam workshop when mod support is out)

### Setting up the Mod Loader
1. Download the latest release of the mod loader from https://github.com/GodotModding/godot-mod-loader/releases/tag/v5.0.1 (scroll to the bottom of that version and there will be an asset called source code)
2. Extract the source code and copy the addons folder
3. Right click the game in steam and click properties. Go to local files and hit browse to pull up the folder for where the game is on your pc
4. Paste the addons folder in the folder you got to from step 3
5. Right click the game in steam again and go to properties. Go to the general tab and paste `--script addons/mod_loader/mod_loader_setup.gd` into the launch options bar

If the game window shows (modded) when you boot up the game that means it worked

### Adding the Mod
1. Go back to the folder you got to in step 3 of the mod loader setup
2. Create a folder called `mods` in that
3. Download the latest version of the mod from https://github.com/Ategon/Dome-Keeper-Moleman/releases/latest
4. Paste the entire zip file **DO NOT EXTRACT IT** into the mods folder you created in step 2

Now boot up the game and the moleman should show up as an option when you go to select a keeper

Enjoy! :)

# Things left to be added
- Art for the upgrades
- Keeper icon in the main menu
- Example movement in the main menu
- Tutorial
- Finalizing the music
- Some more polish on some of the upgrades
- Changing up the way you pick up and drop resources
- Making the tunnels work with all carryables
