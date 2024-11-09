--[[
Congratulations on finding this script file!
Here may can find some explanations and examples on how to break this game in a different ways

# - Not-so-important notice ------------------------------------------------------------------------
    Infinitode 2 uses a custom version of LuaJ, which is basically a scripting engine (roughly)
    compatible with Lua 5.2. One major difference between LuaJ and a regular (C) Lua is... it does not
    always work as defined by the Lua specification in some edge cases. In short, many of the default
    Lua unit tests simply fail, but good news is, they were designed for an extreme situations like
    integer overflows or some weird situations where something isnil() or stuff like that.

    It should not affect most (if any) of your scripts in any way, but in case it does - don't blame
    LuaJ and don't expect things to work strictly according to the Lua specification. Remember that it
    works on top of Java, and Java has different specifications.

    If something does not work at all and you have no idea how to fix it, try to ask some questions in
    our modding Discord server or, if you are completely sure something needs to be fixed - email / DM
    me directly.
# - End of notice  ---------------------------------------------------------------------------------

I assume you are at least slightly familiar with programming / scripting or at least know how this
stuff works or what it does. First of all, this is not a Lua tutorial - you can find one elsewhere,
and I'll just explain some specifics of Lua running in the environment of this game.

I'll start with a few facts about the LuaJ implementation in this game, please keep them in mind:
- All Lua scripts are interpreted, meaning they won't be compiled into platform-specific binaries.
  Interpreted code usually means that doing lots of low-level computations (math, usually) will
  result in a poor performance most of the time. LuaJ may be 2x-3x slower than C Lua in some cases.

  This version of LuaC does not compile into binaries (which are much faster than C Lua) because it
  is not supported on the iOS and because of how serialization works. More on that later.

  Good news is, this is not a regular LuaJ and it has been modified for a faster interaction with
  the game's Java code. And, as in any other interpreted language (for example, Python), you can
  always call already existing Java code which covers most of your needs, and it is very performant.
  For example, let's say you want to sort an array - you can always implement your good ol' Bubble
  sorting (or any other algo) with a pure Lua code (and it will be slow) or you can just create a
  Java array and sort it with the Java's method (which will be very fast).
- Lua can interact with Java's code and objects, that's its purpose and that's what it does most of
  the time. This LuaJ version has been modified in a way to make this interaction clean and
  convenient - most of the time, you can interact with any data type in the same way you'd work with
  a regular Lua tables, with some "if"s here and there - I'll explain them later.
- LuaJ is garbage collected and uses Java's GC. Also it may allocate lots of RAM - don't be afraid
  of that and don't try to optimize it. Java has been made to deal with this kind of shit and it is
  no longer 2010 - allocating lots of memory is ok, don't trust the old articles telling you
  otherwise. One thing to remember though - there are some resources you must dispose of manually
  (for example, textures) but they usually have a dispose() method / LibGDX's documentation says
  that you have to dispose of them, otherwise it may result in memory leaks. You don't have to worry
  about this when working with the usual stuff though, just remember this next time you create a new
  texture / sound / byte stream etc.
- As it has been mentioned earlier - this game runs on top of LibGDX framework so its rules and
  documentation applies to the scripts too.
- This version of LuaJ is sandboxed and is allowed to run only specific set of methods / access
  only specific Java classes. This has been implemented for two reasons - security and performance.
  If you believe you need an access to a class / method not listed there,
  let me know on the Discord server. If you believe that some class or method is too dangerous and
  could potentially harm the player's device (for example, reading / writing files, accessing some
  sensitive data, sending malicious HTTP requests etc), please do the same thing and I'll try to
  sandbox it too.
  Modding / custom maps are not available at the moment I write this only because it could harm
  someone. Scripts can not be shared freely until we test this whole thing and prove it is safe.

### Game's lifecycle
This topic may be covered on our wiki in a better way / with some pictures but I'll talk about it
here too, just to make sure you don't miss it.

Understanding the lifecycle of the app is, probably, the hardest part of getting used to a new
software. Most of the times, you want to find an "entry point" to the game / app and move through
the code to better understand what gets called at what time.

Infinitode's entry point lies in the platform-specific "launchers", as in any project which uses
LibGDX. You don't have to worry about the platform-specific part - all it does is loading of some
libraries, calls some init() methods and prepares the device to run the actual / cross-platform
game-specific code. And, what is more important - you can't affect it in any way through Lua, as
scripts start much later when the game is ready for them.

The lifecycle looks like this:
- Platform-specific code prepares the device and creates an instance of Game (com.prineside.tdi2.Game). .
  There's always a single instance of Game and it is stored as a static field "i" in class Game.
- Game creates, initializes and sets up "managers", in this order. Each manager is responsible for
  different features - for example, AssetManager allows to access different assets (textures /
  texture regions / quads / sounds etc), ResearchManager allows to work with the research tree etc.
- At some point, ScriptManager gets set up, after the majority (if not all) managers are already
  created and set up (meaning you can interact with them). During the setup stage of the ScriptManager,
  it creates a global scripting environment, fills it up with the default fields and functions and then
  executes all the .lua scripts it can find in the "scripts/" folder, in the alphabetical order (
  that's why those files have a prefix like 00_ and 01_ - you can adjust their order of execution by
  modifying their name).
  It skips files starting with underscore (_) - may be useful if you want to exclude some file
  without moving it elsewhere. Also, "local" files have higher priority than an "internal" ones
  (stored in .jar / .apk) so you can overwrite the default files by putting your custom script with
  the same name into scripts/ folder.

  Note: these scripts start at the start of the game and each time the players starts playing some
        level (in a different environment).
        Use these files as your "global libraries" but try not to interact with the game immediately
        when the script runs. You can add new global variables / functions there but be careful -
        they will be serialized in the game's save file and may increase its size.

- After all scripts in the root folder (scripts/) are executed, same happens to the scripts in
  scripts/global/ folder. Same rules apply here (order / priority).

  Note: use scripts in scripts/global/ for your global modifications. Usually these scripts should
        subscribe to the game's events and do anything other than modifying the state of a particular
        run. For this purpose, scripts in scripts/game/ folder or Script tiles should be used.

- The game shows the main menu and starts to trigger events. Scripts may subscribe to the events
  provided by managers (look for FooManager.FooManagerListener interfaces and add them to
  FooManager.listeners) or directly by the game (such as "PreRender" / "Render" etc - use
  addEventHandler for them). At this stage, only "global" script environment is active - the one you
  can interact through the developer console. This environment won't be stored in the save files and
  you should not worry about the correct serialization here.
  If some event is missing, you can just monitor the fields of the managers in the *Render events
  and act on field change. Running such code once per frame should not affect performance.
- From now on, there are two different scenarios that may happen:
  1. Player starts to edit his custom map / a regular map in the dev mode
     In this case, a new scripting environment will be created (completely separate from the
     "global" env, with its own variables) and will run alongside the global environment.
     It will act just like a regular "global" environment, but this time scripts in "scripts/" and
     "scripts/map-editor/" directories will be executed (in this order). Scripts in the Script tiles
     won't be run.
     Additionally, global variable "S" will be set prior to running the scripts in the
     scripts/map-editor directory - it is an instance of GameSystemProvider, which is the main access
     point to anything related to this specific map editing session. It allows to access Systems
     (explanation below) and subscribe to their events (in addition to the events available to the
     global environment).
     When player exits the map editor, this environment will no longer be valid and won't receive
     events from the systems / won't be able to interact with them.

     Note: "Systems" are like "Managers" for one specific game session. They are responsible for
           their specific domain but only exist during a single game session. You can access them
           through the S global variable.

     Note: if your scripts subscribe to the events of managers, make sure to unsubscribe from them
           when player exits the map editor. You can do that in your listener of the SystemDispose
           event - not doing so will result in memory leaks.
           Also, you should not worry about the listeners of systems - they'll be freed up
           automatically. It is even better not to unsubscribe them manually in SystemDispose.

     Note: map editor does not use many of the game's systems as they are not necessary for it, and
           you won't be able to access them through S. For example, there's no WaveSystem or
           EnemySystem.

  2. Player starts playing a level / map
     This case is very similar to the "map editor" scenario but has a couple of differences:
     - Instead of "scripts/map-editor", scripts in "scripts/game" will be executed
     - Global variable "S" will also be set for you and will be available right from the start
       but now it contains much more systems
     - All the scripts from the Script tiles will be executed after those from scripts/game
       directory, left-to-right, bottom-to-top (for example, x0y0, x1y0, x0y1, x1y1 in case of 2x2
       map)
     You should now be much more careful with your scrips as now they affect the game's state and
     will be serialized into the save file (more on the serialization later). Treat these scripts
     like they are not aware of any other script environments and make sure that re-running these
     scripts will result in exactly the same state of the game (do not use global sources of
     randomness / real time / player's global progress / research tree etc)
     You can also subscribe to the global events / events triggered by the managers but make sure
     to unsubscribe from them in SystemDispose.


And that's basically it for the lifecycle. In short:
- Game starts, creates global script environment and executes everything under scripts/ and
  scripts/global there
- Each time player starts playing on some map / opens a map editor, another environment gets created
  with a "S" global variable and executes scripts in scripts/ first, then in scripts/game or
  scripts/map_editor directories. If player has started some map, scripts from Script tiles will be
  executed after all the scripts in the directories
- Scripts can subscribe to a regular events (addEventHandler) / events of specific managers and, in
  case of the "game" environment - additionally to the events of the systems
- When player ends the run / closes the map editor, SystemDispose event gets called where you should
  unsubscribe from the global sources of events (if you have subscribed to them)

### Deterministic game state
(Important for the "game" scripting environment)
Infinitode uses a fixed time step, meaning each update (tick) of the game's state happens at exactly
the same time interval and does not depend on the real time / FPS. By default, it equals to 1/30 s
or 33.333ms per frame. This eliminates the randomness / variations in the regular frame durations
you may usually observe in the FPS and allows to precisely predict what is going on with the game's
state, feeding it only the player's actions and frame (tick / update) numbers.

For example, if player changes the aiming mode in his tower at frame 5 and it starts to rotate
towards some enemy, we only have to store the action ("set aiming mode to...") and frame number (5)
in the replay to simulate his game and get exactly the same result next time we re-play the game
frame by frame (for example, when player continues the game, views his last replays or when his run
is being validated by the server to be added to the leaderboard).

For this reason, scripts in scripts/, scripts/game and in Script tiles (those executed in the
"game" environment) must not affect the game's state in response to the sources of data outside of
the game's state, otherwise it will lead to "desync" - an unpredictable behavior of the game's state
due to some outside factor. Some of such "desync-producing" sources are:
- real time (Gdx.graphics.deltaTime / deltaTime in Render event)
- player's progress outside of the game's state (research tree / inventory etc)
- player's actions (clicks / key presses / GUI or any other direct interaction)
- FastRandom / math.random() and any other source of randomness outside of the game's state
- also avoid using Gdx.app.postRunnable or LibGDX's Timer as they are not tied to the state updates
You can still use any source of data, including those listed above, if you are not going to affect
the state of the game - for example, to update the UI, play sounds or to draw something.

In order to modify the game's state correctly, do it in the predictable way:
- if you need a deltaTime, use the one provided by Update event. Some events may also provide time
  deltas. If you need to run something after some specific interval, just accumulate the "safe"
  deltas in a variable
- if you need to account for player's progress, use info provided by the systems. For example,
  GameValueSystem can be used to retrieve the effects of the research tree (and many other factors)
  at the moment the player has started playing a map. LootSystem can provide some statistics for
  the player's inventory, and most of the game's rules are stored in GameSystemProvider or in the
  GameStateSystem
- to properly react to the player's actions such as clicks / key presses / GUI interactions, such
  actions must first be stored at the specific frames (update numbers) and they will be executed
  only on the next frame (or later, if frame number is set manually). This is like a history of
  player's actions and that's what is being stored in the replays.
  For example, "player has applied a Fireball at 150:231 on frame 1001" will be picked up by the
  AbilitySystem on frame 1001 and will actually apply the ability. If you spawn the ability
  immediately, for example on UI button click, it won't be saved to the history and will ruin the
  replay file - also it will happen in an unpredictable moment in time, probably causing some bugs.
  To store actions, objects of the Action type must be fed to the GameStateSystem (S.gameState).
  Here's how it works:
  - Player has clicked a button
  - Game checks immediately if this action is allowed (for example, player has enough coins). If
    action is not possible at this moment (not enough coins), the game shows a notification and
    does nothing
  - If action is valid, the script creates an Action, configures it (adds some action-specific data
    such as type of the action / coordinates of the mouse click etc, whatever needed) and pushes it
    into GameStateSystem (for the next frame by default)
  - Game "ticks" regularly but some system / listener of the Update event now spots the action. It
    checks again if the action can be performed (enough coins) and if everything's OK, it performs
    the action which affects the state
  It is important to check the validity twice - first for a good user experience, and then for
  cheat-proofing.
- if you need random number generator, use methods provided by GameStateSystem or create your own
  instance of RandomXS128 and seed it with the "safe" data - constant number or number provided by
  GameStateSystem's random generator
- if you need to run something on the next frame (just like Gdx.app.postRunnable()), just store it
  somewhere in the global variables and run on the next Update event. Same goes for the Timer - use
  your own pure-Lua implementation or see if there's one in the scripts/misc
To check for desync issues, enable Sync check in Settings and try playing your map / continuing the
game.

### Serialization
(De)serialization is basically a process of turning the in-memory data into a bunch of bytes for it
to be restored later back into memory, and that's how Infinitode allows to continue any game
immediately. This may also be useful in some other cases - for example, synchronizing players in a
multiplayer session.

Not everything can be serialized though - it may be not safe to deserialize (load bytes into memory)
some objects like file handles or large / complex resources like fonts, textures or UI elements.
That's why Infinitode has a strictly defined list of classes that can be serialized - you can find
it in res/kryo-registry.txt.
The whole Lua VM state, all of the default Lua data types (numbers / strings / tables etc) and
Lua's implementations of Java's interfaces will also be automatically serialized and restored.

In simple words, every object of a serializable class will be stored in a save file and will be
restored when player continues the game, and everything else will simply turn into nil when the
game's state gets restored (player continues the game).

TODO
--]]
