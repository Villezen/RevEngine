package game.world;

import backend.utils.MathUtil;

import flixel.FlxObject;

import flixel.math.FlxPoint;

import flixel.util.FlxSignal.FlxTypedSignal;

typedef TweenParams = 
{
    var time:Float;
    var ease:String;
    var delay:Float;
}

class Pointer extends FlxObject
{
    /**
     * Unlocks the pointer, allowing limitless camera control.
     */
    public var unlocked:Bool = false;

    /**
     * Enables debug mode, which allows manual camera movement using the arrow keys.
     */
    public var debug(default, set):Bool = false;

    function set_debug(value:Bool):Bool
    {
        debugPoint = FlxPoint.get(0, 0);
        return value;
    }

    /**
     * The speed of the pointer's movement.
     */
    public var speed:Float = 0.0;

    /**
     * If the pointer should calculate and apply delta offsets for moving targets.
     */
    public var updateDeltas:Bool = true;

    /**
     * Variable, used to handle the pointer's global movement.
     */
    public var globalPoint:FlxPoint = FlxPoint.get(0, 0);

    /**
     * Internal variable used to handle the dynamic camera which moves depending on the direction the target is singing in.
     */
    private var dynamicPoint:FlxPoint = FlxPoint.get(0, 0);

    /**
     * Internal variable used to handle the delta camera movement.
     */
    private var deltaPoint:FlxPoint = FlxPoint.get(0, 0);

    /**
     * Internal variable used to handle the debug camera.
     */
    private var debugPoint:FlxPoint = FlxPoint.get(0, 0);
    
    /**
     * A snapshot of the target's position when they first get focused on.
     */
    private var baseSnapshot:FlxPoint = FlxPoint.get(0, 0);

    /**
     * The raw distance between the target's current position and their base snapshot.
     */
    private var targetDelta:FlxPoint = FlxPoint.get(0, 0);

    /**
     * The main tween variable, used for this pointer.
     */
    public var tween:FlxTween = null;

    /**
     * Signal dispatched when the pointer has moved.
     */
    public var onCameraMove(default, null):FlxTypedSignal<Character->Void> = new FlxTypedSignal<Character->Void>();

    /**
     * The target the pointer is focused on.
     */
    public var curTarget(default, set):Character;

    var preCharX:Null<Float> = null;
    var preCharY:Null<Float> = null;

    function set_curTarget(?char:Character):Character
    {
        if (curTarget == char && char != null)
            return curTarget;

        if (char == null) 
        {
            curTarget = null;
            return null;
        }

        curTarget = char;

        baseSnapshot.set(char.x, char.y);
        targetDelta.set(0, 0);

        onCameraMove?.dispatch(char);

        move(Std.int(char.x + char.camOffset.x), Std.int(char.y + char.camOffset.y));

        return char;
    }

    public function new(x:Int, y:Int)
    {
        super(0, 0, 1, 1);

        move(x, y, false);
    }

    public function move(newXVal:Int, newYVal:Int, ?tweenEnabled:Bool = true, ?params:TweenParams)
    {
        if (tweenEnabled && speed > 0.0)
        {
            if (params == null)
                params = {time: 1.0, ease: "expoOut", delay: 0.0};

            tween?.cancel();
            tween = FlxTween.tween(globalPoint, {x: newXVal, y: newYVal}, params.time / speed, {ease: Reflect.field(FlxEase, params.ease), startDelay: params.delay});
        }
        else
        {
            globalPoint.set(newXVal, newYVal);
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!debug)
        {
            if (speed > 0.0)
            {
                var dynCam:FlxPoint = curTarget != null ? curTarget.dynCamPoint : null;

                dynamicPoint.x = MathUtil.framerateLerp(dynamicPoint.x, dynCam != null ? dynCam.x : 0.0, 0.04 * speed);
                dynamicPoint.y = MathUtil.framerateLerp(dynamicPoint.y, dynCam != null ? dynCam.y : 0.0, 0.04 * speed);
                
                if (updateDeltas && curTarget != null)
                {
                    targetDelta.set(curTarget.x - baseSnapshot.x, curTarget.y - baseSnapshot.y);

                    deltaPoint.x = MathUtil.framerateLerp(deltaPoint.x, targetDelta.x, 0.08 * speed);
                    deltaPoint.y = MathUtil.framerateLerp(deltaPoint.y, targetDelta.y, 0.08 * speed);
                }
                else
                {
                    deltaPoint.x = MathUtil.framerateLerp(deltaPoint.x, 0.0, 0.08 * speed);
                    deltaPoint.y = MathUtil.framerateLerp(deltaPoint.y, 0.0, 0.08 * speed);
                }

                setPosition((globalPoint.x + (unlocked ? 0 : dynamicPoint.x + deltaPoint.x)), (globalPoint.y + (unlocked ? 0 : dynamicPoint.y + deltaPoint.y)));
            }
            else
            {
                if (updateDeltas && curTarget != null) 
                    deltaPoint.set(curTarget.x - baseSnapshot.x, curTarget.y - baseSnapshot.y);
                
                setPosition((globalPoint.x + deltaPoint.x), (globalPoint.y + deltaPoint.y));
            }

            return;
        }

        //
        // Debugging
        //
        var _speed = FlxG.keys.pressed.SHIFT ? 500 : 250;
        
        if (FlxG.keys.pressed.LEFT)
            debugPoint.x -= _speed * elapsed;
        if (FlxG.keys.pressed.RIGHT)
            debugPoint.x += _speed * elapsed;
        if (FlxG.keys.pressed.UP)
            debugPoint.y -= _speed * elapsed;
        if (FlxG.keys.pressed.DOWN)
            debugPoint.y += _speed * elapsed;

        setPosition((globalPoint.x + debugPoint.x), (globalPoint.y + debugPoint.y));
    }
}
