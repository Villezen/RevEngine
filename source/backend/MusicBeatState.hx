package backend;

import backend.modding.handlers.ModuleHandler;
import backend.modding.IScriptedClass.IEventHandler;
import backend.modding.events.ScriptEvent;
import backend.modding.ModState;
import backend.modding.classes.ScriptedState;
import backend.modding.PolymodManager;

import backend.transition.TransitionLoader;
import backend.transition.TransitionState;

import backend.utils.DebugUtil;

import flixel.FlxState;

/**
 * A specialized FlxState that synchronizes with the `Conductor`.
 */
class MusicBeatState extends FlxState implements IEventHandler
{
	/**
	 * The controls being used for this state.
	 * Defaults to the current instance of the controls.
	 */
	public var controls(get, null):Controls;
	
	function get_controls():Controls
		return Controls.instance;

    /**
	 * The main conductor instance being used in this state.
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
     * The current step, calculated by the Conductor.
     */
    public var currentStep(get, never):Float;
	
	function get_currentStep():Float 
		return conductor.currentStep;

    /**
     * The current beat, calculated by the Conductor.
     */
    public var currentBeat(get, never):Float;

	function get_currentBeat():Float 
		return conductor.currentBeat;

    /**
     * The current measure, calculated by the Conductor.
     */
    public var currentMeasure(get, never):Float;

	function get_currentMeasure():Float 
		return conductor.currentMeasure;

    /**
     * The currently elapsed time of the state.
     */
    public var elapsedTime:Float;

    /**
     * Internal variable that checks if the user is hot reloading to prevent double reloading which can cause crashes.
     */
    private var isResetting:Bool = false;

    /**
     * Reused event instance cause allocating a fresh one every frame feeds the memory for no reason.
     */
    private var _updateEvent:UpdateScriptEvent;

    /**
     * Initializes the state and connects to Conductor signals.
     */
    public override function create():Void
    {
        isResetting = false;
        elapsedTime = 0;

        super.create();

        TransitionLoader.open();

        conductor.onStepHit.add(stepHit);
		conductor.onBeatHit.add(beatHit);
		conductor.onMeasureHit.add(measureHit);

        dispatchEvent(new ScriptEvent(STATE_CREATE));
    }

    /**
     * Standard frame update function which also contains debug functions.
     */
    public override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        elapsedTime += elapsed;

        if (_updateEvent == null)
            _updateEvent = new UpdateScriptEvent(elapsed);

        @:privateAccess
        {
            _updateEvent.elapsed = elapsed;
            _updateEvent.cancelled = false;
            _updateEvent.shouldPropagate = true;
        }

        dispatchEvent(_updateEvent);

        if (FlxG.keys.justPressed.F5 && !isResetting)
            hotReload();
        
        if (FlxG.keys.justPressed.F11 && (subState == null || (subState != null && !(subState is MusicBeatSubState))))
            FlxG.fullscreen = !FlxG.fullscreen;

        if (FlxG.keys.justPressed.F12 && !isResetting)
            emergencyExit();
    }

    /**
     * Calls a set event to every active module.
     * @param event The event name.
     */
    public function dispatchEvent(event:ScriptEvent)
    {
        ModuleHandler.call(event);
    }

    /**
     * Gets called for scripts when an event gets dispatched.
     */
    public function onDispatchEvent(event:ScriptEvent)
    {
        dispatchEvent(event);
    }

    /**
     * Hot-reloads the current state.
     */
    public function hotReload():Void
    {
        isResetting = true;

        TransitionLoader.skipTransitions = true;
        PolymodManager.reloadMods();
        Manager.resetState();

        trace('STATE [${DebugUtil.getStateName()}] RELOADED.\n', 'INFO', true);
    }

    /**
     * Force the game to go back to the main menu state.
     */
    public function emergencyExit():Void
    {
        TransitionLoader.skipTransitions = true;
        Manager.switchState(new menus.MainMenuState());
    }

    /**
     * Cleans up all signal listeneres in the Conductor to prevent any crashes/memory leaks.
     */
    override public function destroy():Void
    {
        FlxG.timeScale = 1.0;

        // Clear up the main conductor instance to destroy it properly
        conductor?.onStepHit.remove(stepHit);
        conductor?.onBeatHit.remove(beatHit);
        conductor?.onMeasureHit.remove(measureHit);
        conductor?.destroy();

        ModuleHandler.clear();

        if (ModState.tracker != null && ModState.tracker.exists(this))
            ModState.tracker.remove(this);

        super.destroy();
    }

    /**
     * Triggered every time the step changes.
     * @param step The current step index.
     */
    public function stepHit(step:Float):Void
    {
        dispatchEvent(new ConductorScriptEvent(STEP_HIT, step, currentBeat, currentMeasure));
    }

    /**
     * Triggered every time the beat changes.
     * @param beat The current beat index.
     */
	public function beatHit(beat:Float):Void
    {
        dispatchEvent(new ConductorScriptEvent(BEAT_HIT, currentStep, beat, currentMeasure));
    }

    /**
     * Triggered every time the measure changes.
     * @param measure The current measure index.
     */
	public function measureHit(measure:Float):Void
    {
        dispatchEvent(new ConductorScriptEvent(MEASURE_HIT, currentStep, currentBeat, measure));
    }
}