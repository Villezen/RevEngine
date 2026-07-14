package game.handlers;

import flixel.util.FlxSignal;

/**
 * A manager for handling BPM-based music events.
 */
class Conductor
{
    public static var instance:Conductor = null;

    /**
     * The current position.
     * Used for calculating the current step, beat, and measure.
     */
    public var position:Float = 0.0;

    /**
     * The start BPM of the Conductor.
     */
    public var startingBpm(default, null):Float;

    /**
     * The current bpm of the Conductor.
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
     * The current step the Conductor is on.
     */
    public var currentStep(default, null):Float = 0;

    /**
     * The current beat the Conductor is on.
     */
    public var currentBeat(default, null):Float = 0;
    
    /**
     * The current measure the Conductor is on.
     */
    public var currentMeasure(default, null):Float = 0;

    /**
     * Signal that fires when the Conductor has reached a new step.
     */
    public var onStepHit(default, null):FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

    /**
     * Signal that fires when the Conductor has reached a new beat.
     */
    public var onBeatHit(default, null):FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

    /**
     * Signal that fires when the Conductor has reached a new measure.
     */
    public var onMeasureHit(default, null):FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

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
	 * Clears the main conductor instance.
	 */
	public function destroy(r:Bool = true)
	{
        reset();
        if (r) instance = null;
	}

    /**
     * Resets the Conductor completely.
     */
    public function reset():Void
    {
        for (i in [currentStep, currentBeat, currentMeasure, position, lastChangeTime, lastChangeStep])
            i = 0.0;

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
            lastChangeStep += (position - lastChangeTime) / stepLengthMs;
        
        lastChangeTime = position;
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
     * Updates the cached crotchet timings to save processing power.
     */
    private inline function updateCachedTimings():Void
    {
        beatLengthMs = (60 / bpm) * 1000;
        stepLengthMs = beatLengthMs / 4;
        measureLengthMs = beatLengthMs * 4;
    }

    /**
     * Updates the Conductor to a new position, and dispatches any signals if necessary.
     * @param newPosition The new position to use.
     */
    public function update(newPosition:Float):Void
    {
        position = newPosition;

        if (stepLengthMs > 0)
            handleStepInfo(newPosition);
    }

    /**
     * Updates the music info for the Conductor based on a position.
     * @param newPosition The position to check.
     */
    private function handleStepInfo(newPosition:Float):Void
    {
        var oldStep:Float = currentStep;
        var oldBeat:Float = currentBeat;
        var oldMeasure:Float = currentMeasure;

        currentStep = Math.floor(lastChangeStep + ((newPosition - lastChangeTime) / stepLengthMs));
        currentBeat = Math.floor(currentStep / 4);
        currentMeasure = Math.floor(currentBeat / 4);
    
        if (oldStep != currentStep) onStepHit.dispatch(currentStep);
        if (oldBeat != currentBeat) onBeatHit.dispatch(currentBeat);
        if (oldMeasure != currentMeasure) onMeasureHit.dispatch(currentMeasure);
    }

    public inline function getBeatLengthMsOf(targetBpm:Float):Float 
    {
        return (60 / targetBpm) * 1000;
    }

    public inline function getStepLengthMsOf(targetBpm:Float):Float 
    {
        return getBeatLengthMsOf(targetBpm) / 4;
    }

    public inline function getmeasureLengthMsOf(targetBpm:Float):Float 
    {
        return getBeatLengthMsOf(targetBpm) * 4;
    }
}