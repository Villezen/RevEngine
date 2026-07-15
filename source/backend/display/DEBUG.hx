package backend.display;

import backend.utils.MathUtil;
import backend.utils.MemoryUtil;

import openfl.display.Sprite;
import openfl.display.Shape;

import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.Lib;

import flixel.math.FlxPoint;

enum DisplayType
{
	HIDDEN;
	SIMPLE;
	MEMORY;
	ADVANCED;
}

/**
 * An OpenFL display object used for displaying the current FPS while playing.
 */
class DEBUG extends Sprite
{
	/**
	 * The current display type.
	 */
	public var currentDisplayType:DisplayType = SIMPLE;

	/**
	 * The box behind the texts, making them more readable.
	 */
	public var textBox:Shape;

	/**
	 * The text displaying the framerate.
	 */
	public var framerateText:TextField;

	/**
	 * The text displaying the framerate.
	 */
	public var memoryText:TextField;

	/**
	 * The graph display for the framerate.
	 */
	public var framerateGraph:GRAPH;

	/**
	 * The graph display for the memory.
	 */
	public var memoryGraph:GRAPH;

	/**
	 * The current frame rate, expressed using frames-per-second
	 */
	public var currentFPS(default, null):Int;

	/**
	 * The maximum framerate recorded.
	 */
	public var peakFPS(default, null):Int;

	/**
	 * Cached variable used for calculating the FPS.
	 */
	private var cacheCount:Int;

	/**
	 * The current tracked time from when the game started.
	 */
	private var currentTime:Float;

	/**
	 * Internal variable used for keeping track of the current time, in terms of milliseconds.
	 */
	private var times:Array<Float>;

  	public function new()
 	{
    	super();

		textBox = new Shape();
        textBox.graphics.beginFill(0x000000);
        textBox.graphics.drawRect(0, 0, 1, 30); 
        textBox.graphics.endFill();
		textBox.alpha = 0.4;
		addChild(textBox);
		
		framerateText = new TextField();
		framerateText.x = 10;
		framerateText.y = 6;
		framerateText.selectable = false;
		framerateText.mouseEnabled = false;
		framerateText.defaultTextFormat = new TextFormat('Monsterrat', 15, 0xFFFFFF);
    	framerateText.text = "FPS: 0";
		addChild(framerateText);

		memoryText = new TextField();
		memoryText.alpha = 0.7;
		memoryText.x = 10;
		memoryText.y = 20;
		memoryText.selectable = false;
		memoryText.mouseEnabled = false;
		memoryText.defaultTextFormat = new TextFormat('Monsterrat', 11, 0xFFFFFF);
    	memoryText.text = "MEM: 0.00mb / 0.00mb";
		addChild(memoryText);

		framerateGraph = new GRAPH(0, 0, 200, 25, 0xFFFFFF);
		framerateGraph.textDisplay.y = -49;
		framerateGraph.minValue = 0;
		addChild(framerateGraph);

		memoryGraph = new GRAPH(0, 0, 200, 25, 0xFFFFFF);
		memoryGraph.textDisplay.y = -49;
		memoryGraph.minValue = 0;
		addChild(memoryGraph);

		currentFPS = 0;
		
		cacheCount = 0;
		currentTime = 0;
		times = [];

    	#if flash
    	addEventListener(Event.ENTER_FRAME, function(e)
		{
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
			times.shift();

		updateFramerate();
		updateMemory();

		updateDisplay(deltaTime);
	}

	/**
	 * Updates the framerate text field.
	 */
	public function updateFramerate()
	{	
		var currentCount = times.length;
		
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		currentFPS = Std.int(Math.min(currentFPS, Std.int(Lib.current.stage.frameRate)));

		if (currentFPS > peakFPS) peakFPS = currentFPS;

		if (currentCount != cacheCount)
		{
			framerateText.text = 'FPS: ${currentFPS}';
			framerateText.width = framerateText.textWidth + 10;
		}

		cacheCount = currentCount;

		if (currentDisplayType == ADVANCED)
		{
			framerateGraph.maxValue = peakFPS;
    		framerateGraph.update(currentCount);
		}

		framerateGraph.x = framerateText.x;
		framerateGraph.y = framerateText.y + framerateText.textHeight + 5;
	}

	public function updateMemory()
	{
		memoryGraph.x = memoryText.x;
		memoryGraph.y = memoryText.y + memoryText.textHeight + 5;

		memoryText.width = memoryText.textWidth + 10;

		var gcMEM:Float = MemoryUtil.roundMemory(MemoryUtil.getGCMemory(), true, true);
		var taskMEM:Float = MemoryUtil.roundMemory(MemoryUtil.getTaskMemory(), true, true);

		memoryText.text = 'MEM: ${gcMEM} ${MemoryUtil.setMemoryUnitString(MemoryUtil.getGCMemory()).toLowerCase()} / ${taskMEM} ${MemoryUtil.setMemoryUnitString((MemoryUtil.getTaskMemory())).toLowerCase()}';
	}

	/**
	 * Updates the display method for the debug texts.
	 */
	public function updateDisplay(dt:Float):Void
	{
		if (FlxG.keys.justPressed.F3)
		{
			switch (currentDisplayType)
            {
                case HIDDEN:
                    currentDisplayType = SIMPLE;
                case SIMPLE:
                    currentDisplayType = MEMORY;
                case MEMORY:
                    currentDisplayType = ADVANCED;
                case ADVANCED:
                    currentDisplayType = HIDDEN;
            }

			trace(currentDisplayType);
		}

		var elapsed:Float = dt / 1000;

		textBox.x = framerateText.x;
		textBox.y = framerateText.y;

        switch(currentDisplayType)
        {
            case HIDDEN:
			{
				textBox.width = MathUtil.smoothLerpPrecision(textBox.width, 0, elapsed, 0.1);
				textBox.height = MathUtil.smoothLerpPrecision(textBox.height, 0, elapsed, 0.1);

				framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, -(framerateText.textWidth + 10), elapsed, 0.1);

				memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, -(memoryText.textWidth + 10), elapsed, 0.1);
				memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

				framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
				memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
			}
            case SIMPLE:
			{
				textBox.width = MathUtil.smoothLerpPrecision(textBox.width, framerateText.textWidth + 7, elapsed, 0.1);
				textBox.height = MathUtil.smoothLerpPrecision(textBox.height, framerateText.textHeight + 5, elapsed, 0.1);

				framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);

				memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, -(memoryText.textWidth + 10), elapsed, 0.1);
				memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

				framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
				memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
			}
            case MEMORY:
			{
				textBox.width = MathUtil.smoothLerpPrecision(textBox.width, memoryText.textWidth + 7, elapsed, 0.1);
				textBox.height = MathUtil.smoothLerpPrecision(textBox.height, framerateText.textHeight + memoryText.textHeight, elapsed, 0.1);

				framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);

				memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, 10, elapsed, 0.1);
				memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 20, elapsed, 0.1);

				framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 0, elapsed, 0.1);
				memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 0, elapsed, 0.1);
			}
            case ADVANCED:
			{
				textBox.width = MathUtil.smoothLerpPrecision(textBox.width, 208, elapsed, 0.1);
				textBox.height = MathUtil.smoothLerpPrecision(textBox.height, memoryText.y + memoryText.textHeight + 33, elapsed, 0.1);

				framerateText.x = MathUtil.smoothLerpPrecision(framerateText.x, 10, elapsed, 0.1);

				memoryText.x = MathUtil.smoothLerpPrecision(memoryText.x, 10, elapsed, 0.1);
				memoryText.y = MathUtil.smoothLerpPrecision(memoryText.y, 60, elapsed, 0.1);

				framerateGraph.alpha = MathUtil.smoothLerpPrecision(framerateGraph.alpha, 1, elapsed, 0.1);
				memoryGraph.alpha = MathUtil.smoothLerpPrecision(memoryGraph.alpha, 1, elapsed, 0.1);
			}
        }
	}
}