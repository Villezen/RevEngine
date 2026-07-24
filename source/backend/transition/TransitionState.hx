package backend.transition;

import flixel.util.FlxSignal;
import sys.FileSystem;
import flixel.FlxCamera;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.util.typeLimit.NextState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
import flixel.group.FlxSpriteGroup;

import backend.modding.handlers.TransitionHandler;

import lime.app.Application;
import backend.MusicBeatSubState;

/**
 * A custom menu used for switching between states.
 */
class TransitionState extends MusicBeatSubState
{
	/**
	 * Whether this menu is currently switching to a new state right now.
	 */
	public static var switchingState:Bool = false;

	/**
	 * Whether this menu is destroyed.
	 * Used to prevent calling the 'finish()' function on a nullified state.
	 */
	private var isDestroyed:Bool = false;

	/**
	 * Toggles the finish function by an external script.
	 */
	private var toggleFinish:Bool = false;

	/**
	 * The group the current scripted transition has inherited.
	 * Explicitly cast as Transition so we can access variables like isStickers.
	 */
	public var group:Transition;

	/**
	 * The new state to switch to.
	 */
	public var newState:NextState;
	
	/**
	 * The camera being used for this state.
	 */
	public var transitionCamera:FlxCamera;
	
	/**
	 * The type of transition being used to switch between states.
	 */
	public var transitionType:String;

	/**
	 * Whether this transition state is transitioning out.
	 */
	private var transOut:Bool = true;

	public function new(?newState:NextState, ?transType:String, ?out:Bool):Void
	{
		super();
		this.newState = newState;
		this.transitionType = transType;
		this.transOut = out;

		if (transitionType == null)
			transitionType = "fade";
	}

	public override function create():Void
	{
		transitionCamera = new FlxCamera();
		transitionCamera.bgColor = 0;
		this.camera = transitionCamera;
		FlxG.cameras.add(transitionCamera, false);

		if (transitionType == "")
		{
			finish();
			return;
		}

		resizeCamera(Application.current.window.width, Application.current.window.height);

		if (!['classicFade', 'fade', 'wipe'].contains(transitionType))
		{
			group = TransitionHandler.spawn(transitionType);

			if (group == null)
			{
				trace('Scripted Transition with alias $transitionType is either invalid or ' + "doesn't exist. Reverting to a generic transition", "ERROR");
				transitionType = 'fade';
			}
			else
			{
				group.camera = transitionCamera;
				group.transIn = !transOut;
				group.transOut = transOut;
				add(group);
				
				group.start();
			}
		}

		switch (transitionType)
		{
			case 'classicFade' | 'fade' | 'wipe':
			{
				var blackSpr:FunkinSprite = new FunkinSprite((-transitionCamera.width), 0).makeGraphic(1, 1, -1);
				blackSpr.scale.set(transitionCamera.width, transitionCamera.height);
				blackSpr.color = 0xFF000000;
				blackSpr.updateHitbox();
				add(blackSpr);

				var endSpr:FunkinSprite = new FunkinSprite(0, 0);
				endSpr.loadGraphic(Paths.image('engine/transition/' + (transitionType != 'wipe' ? 'gradient' : 'box')));
				endSpr.setGraphicSize(transitionCamera.width, transitionCamera.height);
				endSpr.updateHitbox();
				endSpr.screenCenter();
				add(endSpr);

				transitionCamera.angle = (transOut ? 180 : 0);
				transitionCamera.scroll.x = (transOut ? transitionCamera.width : -transitionCamera.width);

				FlxTween.tween(transitionCamera.scroll, {x: (transOut ? -transitionCamera.width : transitionCamera.width)}, .35, {
					ease: FlxEase.linear,
					onComplete: function(_) {
						finish();
					}
				});
			}
		}

		super.create();
	}

	public override function openSubState(subState:FlxSubState):Void
	{
		var isStickerTrans:Bool = (group != null && group.isStickers);

		if (!isStickerTrans && switchingState)
			return;

		if (group != null)
			group.destroyStoredStickers();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (group != null)
		{
			if (group.shouldFinish && !toggleFinish)
			{
				toggleFinish = true;
				finish();
			}
		}
	}

	override public function destroy():Void
	{
		isDestroyed = true;

		if (switchingState)
			return;
			
		if (newState == null && FlxG.cameras.list.contains(transitionCamera))
			FlxG.cameras.remove(transitionCamera);
		else
			transitionCamera.bgColor = 0xFF000000;

		super.destroy();
	}

	override public function close():Void
	{
		if (switchingState)
			return;
		
		TransitionLoader.onTransitionFinish?.dispatch();
		
		super.close();
	}
	
	public function finish():Void
	{
		if (isDestroyed) return;
		
		if (newState != null)
		{
			switchingState = true;
			FlxG.switchState(newState); 
		}
		else
		{
			switchingState = false;
			TransitionLoader.transType = TransitionLoader.defaultTransType; 

			if (group != null && group.isStickers)
				group.destroyStoredStickers();

			this.close();
		}	
	}

	public override function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		resizeCamera(width, height);
	}

	function resizeCamera(width:Int, height:Int):Void
	{
		var ratio:Float = width / height;
		var baseRatio:Float = FlxG.width / FlxG.height;

		var camWidth:Int = FlxG.width;
		var camHeight:Int = FlxG.height;

		if (ratio > baseRatio) 
			camWidth = Std.int(FlxG.height * ratio);
		else 
			camHeight = Std.int(FlxG.width / ratio);

		var camX:Float = -(camWidth - FlxG.width) / 2;
		var camY:Float = -(camHeight - FlxG.height) / 2;

		if (transitionCamera != null)
		{
			transitionCamera.width = camWidth;
			transitionCamera.x = camX;

			transitionCamera.height = camHeight;
			transitionCamera.y = camY;
		}
	}
}