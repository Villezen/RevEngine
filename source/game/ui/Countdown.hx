package game.ui;

import flixel.group.FlxSpriteGroup;
import backend.assets.FunkinSprite;
import flixel.FlxG;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.assets.FunkinSound;

import backend.registries.ui.CountdownRegistry;
import backend.registries.ui.CountdownRegistry.CountdownData;
import backend.registries.ui.CountdownRegistry.CountdownIncrementData;

enum CountdownIncrement
{
    START;
    THREE;
    TWO;
    ONE;
    GO;
    FINISH;
}

typedef CountdownParams =
{
    var skin:String;
    var audio:String;
}

class Countdown extends FlxSpriteGroup
{
    /**
     * What the countdown's initial delay should be.
     */
    public var countdownDelay:Float = Constants.DEFAULT_COUNTDOWN_DELAY;

    /**
     * The class' params.
     */
    public var params:CountdownParams;

    public var data(get, never):CountdownData;

    function get_data():CountdownData
    {
        return CountdownRegistry.get(params.skin);
    }

    /**
     * The current increment of the countdown.
     */
    public var curIncrement(default, set):CountdownIncrement;

    function set_curIncrement(value:CountdownIncrement):CountdownIncrement
    {
        switch (value)
        {
            case THREE, TWO, ONE, GO:
                onIncrement.dispatch(value);
            case FINISH:
                stop();
                onFinish.dispatch();
            default:
        }

        return curIncrement = value;
    }

    /**
     * Whether the Countdown is paused. This means the timer itself isn't running.
     */
    public var paused(get, set):Bool;

    function set_paused(value:Bool):Bool
    {
        if (countdownTimer != null)
            countdownTimer.active = !value;

        return value;
    }

    function get_paused():Bool
        return !countdownTimer?.active ?? true;

    /**
     * Sprite that will display during the countdown's `THREE` increment.
     */
    public var threeSpr:Null<FunkinSprite>;

    /**
     * Sprite that will display during the countdown's `TWO` increment.
     */
    public var twoSpr:Null<FunkinSprite>;

    /**
     * Sprite that will display during the countdown's `ONE` increment.
     */
    public var oneSpr:Null<FunkinSprite>;

    /**
     * Sprite that will display during the countdown's `GO` increment.
     */
    public var goSpr:Null<FunkinSprite>;

    /**
     * The timer used for this countdown to help with counting down.
     */
    public var countdownTimer(default, null):FlxTimer;

    /**
     * Signal that fires when the Countdown has started.
     */
    public var onStart(default, null):FlxSignal = new FlxSignal();

    /**
     * Signal that fires when the Countdown changes to a new state.
     */
    public var onIncrement(default, null):FlxTypedSignal<CountdownIncrement->Void> = new FlxTypedSignal<CountdownIncrement->Void>();

    /**
     * Signal that fires when the Countdown finishes.
     */
    public var onFinish(default, null):FlxSignal = new FlxSignal();

    /**
     * A map storing each loaded intro sound to prevent overlap and memory leaks.
     */
    public var introSounds:Map<String, FunkinSound> = new Map<String, FunkinSound>();

    public function new(params:CountdownParams)
    {
        super();

        this.params = params;

        threeSpr = createSprite(THREE);
        twoSpr = createSprite(TWO);
        oneSpr = createSprite(ONE);
        goSpr = createSprite(GO);

        curIncrement = START;
    }

    /**
     * Gets the sprite that displays during the specified increment.
     * @return The sprite, or null if the skin has no image for it.
     */
    public function getSprite(increment:CountdownIncrement):Null<FunkinSprite>
    {
        return switch (increment)
        {
            case THREE: threeSpr;
            case TWO: twoSpr;
            case ONE: oneSpr;
            case GO: goSpr;
            default: null;
        }
    }

    /**
     * Gets the skin's data entry for the specified increment.
     */
    public function getEntry(increment:CountdownIncrement):Null<CountdownIncrementData>
    {
        var increments = data?.increments;

        if (increments == null)
            return null;

        return switch (increment)
        {
            case THREE: increments.THREE;
            case TWO: increments.TWO;
            case ONE: increments.ONE;
            case GO: increments.GO;
            default: null;
        }
    }

    /**
     * Gets the image file name for the specified increment.
     */
    function getImageName(increment:CountdownIncrement):Null<String>
    {
        return switch (increment)
        {
            case THREE: 'threeSpr';
            case TWO: 'twoSpr';
            case ONE: 'oneSpr';
            case GO: 'goSpr';
            default: null;
        }
    }

    /**
     * Builds and adds the sprite for the specified increment.
     * @return The new sprite, or null if the skin has no image for it.
     */
    function createSprite(increment:CountdownIncrement):Null<FunkinSprite>
    {
        var entry = getEntry(increment);
        var image = getImageName(increment);

        if (entry == null || image == null)
            return null;

        var path = 'game/ui/countdown/${params.skin}/$image';

        if (!Paths.exists('images/$path.png'))
            return null;

        var spr = new FunkinSprite();

        if (entry.animation != null && Paths.exists('images/$path.xml'))
        {
            spr.frames = Paths.getSparrowAtlas(path);
            spr.animation.addByPrefix("anim", entry.animation.prefix, entry.animation.fps, entry.animation.looped);
        }
        else
            spr.loadGraphic(Paths.image(path));

        spr.antialiasing = entry.antialiasing;
        spr.scale.set(entry.scale[0], entry.scale[1]);
        spr.alpha = 0;
        spr.angle = entry.angle;

        spr.updateHitbox();
        centerSprite(spr, entry);

        add(spr);
        return spr;
    }

    /**
     * Centers a sprite on the camera, applying the entry's offsets.
     */
    function centerSprite(spr:FunkinSprite, entry:CountdownIncrementData):Void
    {
        spr.setPosition((Std.int(camera.width - spr.width) / 2) + entry.offsets[0], (Std.int(camera.height - spr.height) / 2) + entry.offsets[1]);
    }

    /**
     * Changes the state of the Countdown based on it's current state.
     */
    function increment()
    {
        curIncrement = switch (curIncrement)
        {
            case START: THREE;
            case THREE: TWO;
            case TWO: ONE;
            case ONE: GO;
            case GO: FINISH;
            default: START;
        }
    }

    /**
     * Starts the countdown timer.
     */
    public function start()
    {
        onStart.dispatch();

        countdownTimer = new FlxTimer().start(Conductor.instance.beatLengthMs / 1000, function(tmr:FlxTimer)
        {
            increment();

            playGraphicAnimation(curIncrement);
            playSound(curIncrement);
        }, 5);
    }

    /**
     * Restarts the countdown from the beginning.
     */
    public function restart()
    {
        countdownTimer?.cancel();
        curIncrement = START;
    }

    /**
     * Completely stops the countdown, and resets it.
     */
    public function stop()
    {
        if (countdownTimer != null)
        {
            countdownTimer.cancel();
            countdownTimer = null;
        }

        curIncrement = START;
    }

    /**
     * Shows and fades out the graphic for the specified increment, if the skin has one.
     * @param increment The increment to display the graphic for.
     */
    function playGraphicAnimation(increment:CountdownIncrement)
    {
        var spr = getSprite(increment);
        var entry = getEntry(increment);

        if (spr == null || entry == null)
            return;

        spr.alpha = entry.alpha;

        if (spr.animation.getByName("anim") != null)
            spr.animation.play("anim", true);

        FlxTween.tween(spr, {alpha: 0}, Conductor.instance.beatLengthMs / 1000, {ease: FlxEase.cubeInOut});
    }

    /**
     * Plays the sound related to the specified increment.
     * @param increment The increment to play the sound asset for.
     */
    function playSound(increment:CountdownIncrement)
    {
        for (snd in introSounds)
        {
            if (snd != null)
                snd.stop();
        }

        var sound:Null<String> = getSound(increment);

        if (sound == null)
            return;

        if (!introSounds.exists(sound))
        {
            var asset = Paths.sound('gameplay/intro/${params.audio}/$sound');

            if (asset == null)
                return;

            var newSnd = FunkinSound.load(asset, 0.6, false, false, false, false, null, null, true);

            if (newSnd == null)
                return;

            introSounds.set(sound, newSnd);
        }

        introSounds.get(sound)?.play(true);
    }

    /**
     * Gets the sound asset related to the specified increment.
     * @param increment The increment to get the sound asset for.
     * @return A string representing the file name of the increment.
     */
    function getSound(increment:CountdownIncrement):Null<String>
    {
        return switch (increment)
        {
            case THREE: 'intro3';
            case TWO: 'intro2';
            case ONE: 'intro1';
            case GO: 'introGo';
            default: null;
        }
    }

    /**
     * Syncs the countdown to the camera's dimensions.
     */
    public function sync():Void
    {
        for (increment in [THREE, TWO, ONE, GO])
        {
            var spr = getSprite(increment);
            var entry = getEntry(increment);

            if (spr == null || entry == null)
                continue;

            centerSprite(spr, entry);
        }
    }

    /**
     * Safely destroys cached sounds to prevent memory stacking when switching states.
     */
    override public function destroy()
    {
        for (snd in introSounds)
        {
            if (snd != null)
            {
                snd.stop();
                snd.destroy();
            }
        }
        introSounds.clear();

        super.destroy();
    }
}
