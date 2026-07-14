package backend.display;

import backend.display.MEM;
import backend.display.FPS;

import openfl.display.Sprite;
import openfl.display.Shape;

/**
 * An OpenFL display graphic used as a background while displaying debug information like the FPS, and Memory Counter.
 */
class BOX extends Sprite
{
	/**
	 * The current tracked time from when the game started.
	 */
	@:noCompletion private var currentTime:Float;

	/**
	 * The box used as a background while display debug information.
	 */
	var blackBox:Shape;

  	public function new(x:Float = 10, y:Float = 10)
 	{
    	super();

    	this.x = x;
   	 	this.y = y;

		blackBox = new Shape();
        blackBox.graphics.beginFill(0x000000);
        blackBox.graphics.drawRect(0, 0, 1, 30); 
        blackBox.graphics.endFill();
		blackBox.alpha = 0.4;
		blackBox.x -= 1;
		this.addChild(blackBox);

		currentTime = 0;
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
		blackBox.width = FPS.daWidth + MEM.daWidth + 20;
	}
}