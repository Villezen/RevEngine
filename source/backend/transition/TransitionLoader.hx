package backend.transition;

import flixel.util.FlxSignal;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;

/**
 * A class used for handling general transitions for states, as well as performing custom transitions.
 */
class TransitionLoader
{
	/**
	 * Call a signal when a transition has been finished.
	 */
	public static var onTransitionFinish:FlxSignal = new FlxSignal();
	
	/**
	 * The current transition to use when transitioning in-between states.
	 */
	public static var transType:String = defaultTransType;

	/**
	 * Whether to skip the 'out' part of a transition where the transition is going away.
	 */
	public static var skipTransOut:Bool = false;
	
	/**
	 * Whether to skip the 'in' part of a transition where the transition is coming in.
	 */
	public static var skipTransIn:Bool = false;

	/**
	 * Whether to skip transitions completely.
	 */
	public static var skipTransitions:Bool = false;

	/**
	 * The default transition to use when transitioning in-between states.
	 */
	public static final defaultTransType:String = "classicFade";

    /**
     * Switch to a different state while preparing to purge the cached assets and also display a neat Out Transition.
	 * 
     * @param nextState The State that you want to switch to.
     * @param type The Transition type that will be displayed: (classicFade, stickers, box, snes).
     */
    public static function switchState(nextState:NextState, ?type:String):Void 
    {
		if (type != null) transType = type;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		if (skipTransitions || skipTransOut)
		{
            FlxG.switchState(nextState);
			FlxG.state.openSubState(new TransitionState(nextState, ''));

            return;
        }

		FlxG.state.persistentUpdate = false;
		FlxG.state.openSubState(new TransitionState(nextState, transType, true));
	}
	
	/**
	 *  This is called on create() by MusicBeatState by default already! 
	 *  !! If for some reason you are using FlxState instead of MusicBeatState (psycho), you should call this on create at your state !!
	 * 
	 *  Clears the assets that were previously set to be cleared from the cache and displays the In Transition.
	 */
    public static function open():Void // for create() on states
	{ 
		if (skipTransitions || skipTransIn)
		{
			FlxG.state.openSubState(new TransitionState(null, '', false));

			setFalse();
            return;
        }

		FlxG.state.openSubState(new TransitionState(null, transType, false));
		setFalse();
	}

	/**
	 * Resets the properties of this class.
	 */
	static function setFalse():Void
	{
		skipTransOut = false;
		skipTransIn = false;
		skipTransitions = false;
	}
}