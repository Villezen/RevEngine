package backend;

import flixel.FlxGame;

import backend.display.DEBUG;

import haxe.io.Path;

import lime.graphics.Image;
import lime.app.Application;

import openfl.Lib;
import openfl.display.Sprite;

import backend.utils.ThreadUtil;
import backend.utils.WindowUtil;

/**
 * Sprite that serves as the root container of the application.
 */
class Main extends Sprite
{
    /**
	 * The debug display sprite, showing you info about the current framerate, memory usage and more. 
	 */
	public static var debugDisplay:DEBUG;

    /**
     * Creates the game child, alongside a bunch of display sprites.
     */
    public function new()
    {
		Sys.setCwd(Path.directory(Sys.programPath()));
		Sys.println('');

        super();

        var game:FlxGame = new FlxGame(1280, 720, backend.Initialize, 144, 144, true, false);

		@:privateAccess
        game._customSoundTray = backend.display.SOUNDTRAY;
        addChild(game);

		debugDisplay = new DEBUG();
		addChild(debugDisplay);
    }
}
