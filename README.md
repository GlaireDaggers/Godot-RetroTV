# Godot-RetroTV
Authentic TV shaders for Godot 4.x with accurate composite video artifacts

## Overview

The main effect is in the `crt_effect` script, which inherits from Node2D. It
takes a Texture2D as input, which will be encoded as NTSC composite video and
then decoded back into RGB and drawn to the viewport.
Additionally, the `crt_screen` script provides a fullscreen effect which gives
the appearance of a curved CRT along with a configurable shadow mask overlay and
scanlines.

## Usage

In general, you would create a SubViewport to draw your game, setting its size
to some resolution (for instance, you might pick 320x240 for a game styled after
PSX or Saturn games).
Then you'd create a CRTEffect node, and set its Input Texture to a new
ViewportTexture referencing the SubViewport you created. You can also optionally
create a CRTScreen node to apply the TV effects.
