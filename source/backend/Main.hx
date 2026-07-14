package backend;

import flixel.FlxGame;

import backend.display.FPS;
import backend.display.MEM;
import backend.display.BOX;

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
	 * A frames per second counter which is displayed at the top left corner.
	 */
	public static var framerateCounter:FPS;

	/**
	 * A set of memory counters, displayed at the top left positioned next to the framerate counter.
	 */
	public static var memoryCounter:MEM;

	/**
	 * A black rectangular background sprite, which sits behind these previous debug display texts.
	 */
	public static var displayBox:BOX;

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

        displayBox = new BOX(10, 5);

		framerateCounter = new FPS(10, 6, 0xFFFFFF, 'exo2.otf');
		memoryCounter = new MEM(10, 8, 0xFFFFFF, 'exo2.otf');

		for (debugDisplay in [displayBox, framerateCounter, memoryCounter])
			addChild(debugDisplay);
    }

	// Temporary (?)
	public static function execAsync(func:Void->Void) ThreadUtil.execAsync(func);
}
