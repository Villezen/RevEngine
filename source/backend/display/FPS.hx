package backend.display;

import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.Lib;

/**
 * An OpenFL display object used for displaying the current FPS while playing.
 */
class FPS extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
	 * Internal variable for keeping track of the width of the object.
	 */
	public static var daWidth:Float = 0;

	/**
	 * The current tracked time from when the game started.
	 */
	@:noCompletion private var currentTime:Float;

	/**
	 * Cached variable used for calculating the FPS.
	 */
	@:noCompletion private var cacheCount:Int;

	/**
	 * Internal variable used for keeping track of the current time, in terms of milliseconds.
	 */
	@:noCompletion private var times:Array<Float>;

  	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000, font:String = 'exo2.otf')
 	{
    	super();

    	this.x = x;
   	 	this.y = y;
    	this.selectable = false;
    	this.mouseEnabled = false;
		
		currentFPS = 0;
		defaultTextFormat = new TextFormat('Monsterrat', 18, color);
    	text = "";

		cacheCount = 0;
		currentTime = 0;
		times = [];

    	#if flash
    	addEventListener(Event.ENTER_FRAME, function(e) {
     	 var time = Lib.getTimer();
     	 __enterFrame(time - currentTime);
    	});
    	#end
  	}

  	/**
  	 * Event Handlers.
  	 */
  	@:noCompletion
  	#if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		currentTime += deltaTime;

		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		var currentCount = times.length;
		
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		currentFPS = Std.int(Math.min(currentFPS, Std.int(Lib.current.stage.frameRate)));

		if (currentCount != cacheCount)
		{
			text = '${currentFPS} FPS';
			width = textWidth + 10;
		}

		cacheCount = currentCount;
		daWidth = this.textWidth;
	}
}