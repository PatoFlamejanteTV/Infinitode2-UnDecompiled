To make your resource pack visible to the game, place it into directory 'resourcepacks' next to the game executable.
Resource pack directory name can't contain any symbol except ._-a-z0-9.
There must be a pack.json file in pack directory, other files are optional.

Example of pack.json (comments inside .json are not allowed, make sure you remove them):

{
  /*
    An array of texture atlases.
    Atlases are loaded in order of this array. All regions from atlas are loaded, then the game loads next atlas. If
    next atlas has no new region names, it is skipped. If any of atlas textures is too large for device hardware, it is
    skipped.
    In the default resource pack, "combined.atlas" has a bigger texture and contains all regions from "skin.atlas",
    "towers.atlas" and "ui.atlas". It was made to make sure all devices can load all regions (each of smaller atlases
    have textures that not exceed 2048x2048 texture size limit).
    If the game can't find some region, it will search for it in the higher resource packs or fall back to default
    textures.
    Tips of how to create a texture atlas are listed below.
  */
  "atlases": [
    "textures/combined.atlas",
    "textures/skin.atlas",
    "textures/towers.atlas",
    "textures/ui.atlas"
  ],
  /*
    Custom font.
    Tips of how to create a custom font are listed below.
  */
  "font": {
    /* Font symbols map file. */
    "file": "font.fnt",
    /* Name of texture region which contains font characters. */
    "texture": "sdf-font",
    /* Size of characters in the texture, if SDF texture is used. More details below. */
    "sdf_resolution": 32
  },
  /*
    Menu music.
    .zxm = .xm in .zip
  */
  "menuXmSoundTrack": "menu-music-zxm",
  /*
    Colors.
    List of colors can be found in default's resource pack pack.json.
    Colors must be defined as #RRGGBB or #RRGGBBAA. Any color may be skipped, in this case game will fall back through
    higher resource packs to defaults.
  */
  "colors": {
    "background": "#171717FF",
    "button_regular_up": "#0277BDFF",
    "button_regular_down": "#01579BFF",
    "button_regular_hover": "#0288D1FF",
    "text_regular": "#FFFFFFFF",
    "text_link": "#4FC3F7FF",
    "overlay": "#0D0D0D8F"
  }
}

== Texture atlases ==
Texture atlases are made with "GDX texture packer" tool: https://github.com/crashinvaders/gdx-texture-packer-gui.
All packs usually have next configuration:
  File format: PNG
  Color format: RGBA8888
  Min filter: MipMapLinearNearest (Required setting! MipMaps are used by the game. If textures are rendered as black squares, check this field)
  Mag filter: Linear
  Padding X/Y: 4-8 (Use higher values to avoid color bleeding)
  Wrap X/Y: Any (Game forces this to Repeat)
  Edge padding: enabled
  Duplicate padding: enabled (Used in couple with Padding to avoid color bleeding)
  Strip whitespace: disabled
  Allow rotation: disabled
  Bleeding: enabled
  Force POT: enabled
Tips:
- If you see black squares instead of textures, make sure Min filter is set to MipMapLinearNearest.
- For better performance, try to pack all textures into fewer amount of atlases. If game can't find any texture region
  in your pack, it will use region from higher resource packs or from default - try to avoid this for textures that are
  used frequently to avoid excessive texture switches by packing default textures into your atlases.
- Textures can have any size but it is preferred to keep the original aspect ratio.
- Texture regions with "sdf-" prefix are SDFs (see below).

== Fonts ==
Fonts are usually packed with Hiero (https://github.com/libgdx/libgdx/wiki/Hiero) with "Distance field" setting (see DFF
below). Font texture region name must start with "sdf-" to be rendered properly.

== Signed distance field textures (SDF) ==
https://github.com/libgdx/libgdx/wiki/Distance-field-fonts