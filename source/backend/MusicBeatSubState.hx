package backend;

import flixel.FlxSubState;
import flixel.FlxState;

import backend.modding.PolymodManager;
import backend.modding.ModSubState;

import backend.utils.DebugUtil;

class MusicBeatSubState extends FlxSubState
{
    /**
     * The parent state this substate is being opened in.
     * Retrieves the internal _parentState from FlxSubState.
     */
    public var parent(get, set):Dynamic;

    function get_parent():Dynamic
    {
        return _parentState;
    }

    function set_parent(value:Dynamic):Dynamic
    {
        _parentState = value;
        return _parentState;
    }

    /**
	 * The controls being used for this substate.
	 * Defaults to the current instance of the controls.
	 */
	public var controls(get, null):Controls;
    
	function get_controls():Controls
		return Controls.instance;
	
    /**
	 * The main conductor instance being used in this substate.
	 */
	public var conductor(get, null):Conductor;
	
	function get_conductor():Conductor
    {
        if (Conductor.instance == null)
        {
            Conductor.instance = new Conductor();
        }

		return Conductor.instance;
    }

	/**
	 * The current step of the substate.
	 * Defaults to the Conductor's current step.
	 */
	public var currentStep(get, never):Int;
	
	function get_currentStep():Int
		return conductor.currentStep;
	
	/**
	 * The current beat of the substate.
	 * Defaults to the Conductor's current beat.
	 */
	public var currentBeat(get, never):Int;
	function get_currentBeat():Int 
		return conductor.currentBeat;

	/**
	 * The current measure of the substate.
	 * Defaults to the Conductor's current measure.
	 */
	public var currentMeasure(get, never):Int;

	function get_currentMeasure():Int 
		return conductor.currentMeasure;

    /**
     * The currently elapsed time of the state.
     */
    public var elapsedTime:Float;

    public override function create()
    {
        super.create();

		conductor.onStepHit.add(stepHit);
		conductor.onBeatHit.add(beatHit);
		conductor.onMeasureHit.add(measureHit);
    }

    /**
     * Cleans up all signal listeneres in the Conductor to prevent any crashes/memory leaks.
     */
    override public function destroy():Void
    {
        //conductor.destroy(false);

        FlxG.timeScale = 1.0;

        if (ModSubState.tracker != null && ModSubState.tracker.exists(this))
            ModSubState.tracker.remove(this);

        super.destroy();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        elapsedTime += elapsed;

        if (FlxG.keys.justPressed.F5 || FlxG.keys.justPressed.F6)
        {
            Manager.resetState();
            trace('STATE [${DebugUtil.getStateName()}] RELOADED.\n', 'INFO', true);
        }

        if (FlxG.keys.justPressed.F11)
            FlxG.fullscreen = !FlxG.fullscreen;
    }

    /**
     * Triggered every time the step changes.
     * @param step The current step index.
     */
    public function stepHit(step:Int):Void {}

    /**
     * Triggered every time the beat changes.
     * @param beat The current beat index.
     */
	public function beatHit(beat:Int):Void {}

    /**
     * Triggered every time the measure changes.
     * @param measure The current measure index.
     */
	public function measureHit(measure:Int):Void {}
}