package game.handlers;

import flixel.util.FlxSignal;
import flixel.math.FlxMath;

/**
 * A manager for handling BPM-based music events.
 */
class Conductor
{
    public static var instance:Conductor = null;

    /**
     * The current position of the song.
     * Used for calculating the current step, beat, and measure.
     */
    public var songPosition:Float = 0.0;

    /**
     * The initial BPM of the Conductor.
     */
    public var startingBpm(default, null):Float;

    /**
     * The current bpm of the song.
     */
    public var bpm:Float = 100;

    /**
     * Timing Variables.
     */
    public var stepLengthMs:Float = 0;
    public var beatLengthMs:Float = 0;
    public var measureLengthMs:Float = 0;

    /**
     * BPM Change Anchors.
     */
    private var lastChangeTime:Float = 0.0;
    private var lastChangeStep:Float = 0.0;

    /**
     * Active BPM tween.
     */
    public var bpmTween:FlxTween;

    /**
     * Internal flag to prevent manual BPM changes overlapping with the tween.
     */
    private var isTweeningBPM:Bool = false;

	/**
	 * Current position in the song, in steps and fractions of itself.
	 */
    public var currentStepTime(default, null):Float = 0;

    /**
	 * Current position in the song, in beats and fractions of itself.
	 */
    public var currentBeatTime(default, null):Float = 0;
    
	/**
	 * Current position in the song, in measures and fractions of itself.
	 */
    public var currentMeasureTime(default, null):Float = 0;

    /**
     * The current step the Conductor is on.
     */
    public var currentStep(default, null):Int = 0;

    /**
     * The current beat the Conductor is on.
     */
    public var currentBeat(default, null):Int = 0;
    
    /**
     * The current measure the Conductor is on.
     */
    public var currentMeasure(default, null):Int = 0;

    /**
     * Signal that fires when the Conductor has reached a new step.
     */
    public var onStepHit(default, null):FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

    /**
     * Signal that fires when the Conductor has reached a new beat.
     */
    public var onBeatHit(default, null):FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

    /**
     * Signal that fires when the Conductor has reached a new measure.
     */
    public var onMeasureHit(default, null):FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

    /**
     * Signal that fires when the Conductor has reached a new BPM change event.
     */
    public var onBPMChange(default, null):FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

    /**
	 * Constructor.
	 */
	public function new() 
	{

	}

	/**
	 * Resets and clears the main conductor instance..
	 */
	public function destroy()
	{
        // Make sure we cancel all the tweens in this instance before we destroy it.
        reset();

        // Destroy this instance.
        instance = null;
	}

    /**
     * Completely resets the conductor.
     */
    public function reset():Void
    {
        songPosition = 0.0;
        lastChangeTime = 0.0;
        lastChangeStep = 0.0;

        currentStepTime = 0;
        currentBeatTime = 0;
        currentMeasureTime = 0;

        currentStep = 0;
        currentBeat = 0;
        currentMeasure = 0;

        cancelBPMTween();
        onBPMChange.removeAll();
    }

    /**
     * Safely cancels any active BPM transition.
     */
    private inline function cancelBPMTween():Void
    {
        if (bpmTween != null)
        {
            bpmTween.cancel();
            bpmTween = null;
            isTweeningBPM = false;
        }
    }

    /**
     * Sets the initial bpm and computes cached lengths.
     * @param newBpm The bpm to set the Conductor to.
     */
    public function setBPM(newBpm:Float):Void
    {
        if (newBpm <= 0) return;

        cancelBPMTween();

        startingBpm = newBpm;
        bpm = newBpm;
        
        updateCachedTimings();
    }

    /**
     * Changes the current bpm dynamically (intended for use via Events).
     * @param newBpm The new bpm to change to.
     */
    public function changeBPM(newBpm:Float):Void
    {
        if (newBpm <= 0 || newBpm == bpm) return;

        if (!isTweeningBPM)
            cancelBPMTween();

        if (stepLengthMs > 0)
            lastChangeStep += (songPosition - lastChangeTime) / stepLengthMs;
        
        lastChangeTime = songPosition;
        bpm = newBpm;

        updateCachedTimings();
        
        onBPMChange.dispatch(bpm);
    }

    /**
     * Linearly transitions the BPM to a new value over a specified number of steps.
     * @param newBpm The target BPM to tween to.
     * @param steps The duration of the tween, measured in steps based on the CURRENT BPM.
     */
    public function changeBPMLinear(newBpm:Float, steps:Float):Void
    {
        if (newBpm <= 0 || newBpm == bpm) return;

        cancelBPMTween();

        var duration:Float = (steps * stepLengthMs) / 1000;

        if (duration <= 0)
        {
            changeBPM(newBpm);
            return;
        }

        bpmTween = FlxTween.num(bpm, newBpm, duration, 
            {
                onComplete: function(twn:FlxTween)
                {
                    bpmTween = null;
                    isTweeningBPM = false;
                }
            },
            function(value:Float)
            {
                isTweeningBPM = true;
                changeBPM(value);
                isTweeningBPM = false;
            }
        );
    }

    /**
     * Updates the cached length timings to save processing power.
     */
    private inline function updateCachedTimings():Void
    {
        beatLengthMs = getBeatLengthMsOf(bpm);
        stepLengthMs = beatLengthMs / 4;
        measureLengthMs = beatLengthMs * 4;
    }

    /**
     * Updates the Conductor to a new position, and dispatches any signals if necessary.
     * @param newPosition The new position to use.
     */
    public function update(newPosition:Float):Void
    {
        songPosition = newPosition;

        if (stepLengthMs > 0)
            handleStepInfo(newPosition);
    }

    /**
     * Jumps straight to a position without dispatching the steps in between.
     * @param newPosition The position to jump to.
     */
    public function seek(newPosition:Float):Void
    {
        songPosition = newPosition;

        if (stepLengthMs > 0)
            applyPositionInfo(newPosition);
    }

    /**
     * Recalculates the cached step, beat and measure values for a position.
     * @param newPosition The position to calculate from.
     */
    private inline function applyPositionInfo(newPosition:Float):Void
    {
        currentStepTime = FlxMath.roundDecimal(lastChangeStep + ((newPosition - lastChangeTime) / stepLengthMs), 4);
        currentBeatTime = FlxMath.roundDecimal((currentStepTime / 4), 4);
        currentMeasureTime = FlxMath.roundDecimal((currentBeatTime / 4), 4);

        currentStep = Math.floor(currentStepTime);
        currentBeat = Math.floor(currentBeatTime);
        currentMeasure = Math.floor(currentMeasureTime);
    }

    /**
     * Updates the music info for the Conductor based on a position.
     * @param newPosition The position to check.
     */
    private function handleStepInfo(newPosition:Float):Void
    {
        final oldStep:Int = currentStep;
        final oldBeat:Int = currentBeat;
        final oldMeasure:Int = currentMeasure;

        applyPositionInfo(newPosition);

        // Update the song's meter values while checking that it's not trying to repeat a beat.
        // This gets done in a loop between the old and current step to dispatch to make sure
        // we never skip a value, thus preventing breaking stuff like events.
        if (currentStep > oldStep) 
            for (s in oldStep...currentStep) onStepHit.dispatch(s+1);

        if (currentBeat > oldBeat) 
            for (b in oldBeat...currentBeat) onBeatHit.dispatch(b+1);
        
        if (currentMeasure > oldMeasure) 
            for (m in oldMeasure...currentMeasure) onMeasureHit.dispatch(m+1);
    }

    public inline function getBeatLengthMsOf(targetBpm:Float):Float 
    {
        return (60 / targetBpm) * 1000;
    }

    public inline function getStepLengthMsOf(targetBpm:Float):Float 
    {
        return getBeatLengthMsOf(targetBpm) / 4;
    }

    public inline function getMeasureLengthMsOf(targetBpm:Float):Float 
    {
        return getBeatLengthMsOf(targetBpm) * 4;
    }
}