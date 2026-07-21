#if !macro
import flixel.FlxG;

import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import flash.display.BlendMode; 

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import backend.Manager;
import backend.Configs;
import backend.Controls;
import backend.Constants;

import backend.assets.AtlasText;
import backend.assets.FunkinBitmapText;
import backend.assets.FunkinSound;
import backend.assets.FunkinSprite;
import backend.assets.Paths;

import game.handlers.Conductor;

import backend.registries.misc.ConfigRegistry;

using StringTools;
using backend.utils.tools.IteratorTools;
using backend.utils.tools.TagTools;
#end