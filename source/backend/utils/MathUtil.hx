package backend.utils;

import flixel.math.FlxMath;

/**
 * A utility used for providing several functions relating to Math equations, and expressions.
 */
class MathUtil
{
  /**
   * Linear interpolation.
   *
   * @param base The starting value, when `alpha = 0`.
   * @param target The ending value, when `alpha = 1`.
   * @param alpha The percentage of the interpolation from `base` to `target`. Forms a "line" intersecting the two.
   *
   * @return The interpolated value.
   */
  public static function lerp(base:Float, target:Float, alpha:Float):Float
  {
    if (alpha == 0) return base;
    if (alpha == 1) return target;
    return base + alpha * (target - base);
  }

  /**
   * Exponential decay interpolation.
   *
   * Framerate-independent because the rate-of-change is proportional to the difference, so you can
   * use the time elapsed since the last frame as `deltaTime` and the function will be consistent.
   *
   * Equivalent to `smoothLerpPrecision(base, target, deltaTime, halfLife, 0.5)`.
   *
   * @param base The starting or current value.
   * @param target The value this function approaches.
   * @param deltaTime The change in time along the function in seconds.
   * @param halfLife Time in seconds to reach halfway to `target`.
   *
   * @see https://twitter.com/FreyaHolmer/status/1757918211679650262
   *
   * @return The interpolated value.
   */
  public static function smoothLerpDecay(base:Float, target:Float, deltaTime:Float, halfLife:Float):Float
  {
    if (deltaTime == 0) return base;
    if (base == target) return target;
    return lerp(target, base, exp2(-deltaTime / halfLife));
  }

  /**
   * Exponential decay interpolation.
   *
   * Framerate-independent because the rate-of-change is proportional to the difference, so you can
   * use the time elapsed since the last frame as `deltaTime` and the function will be consistent.
   *
   * Equivalent to `smoothLerpDecay(base, target, deltaTime, -duration / logBase(2, precision))`.
   *
   * @param base The starting or current value.
   * @param target The value this function approaches.
   * @param deltaTime The change in time along the function in seconds.
   * @param duration Time in seconds to reach `target` within `precision`, relative to the original distance.
   * @param precision Relative target precision of the interpolation. Defaults to 1% distance remaining.
   *
   * @see https://twitter.com/FreyaHolmer/status/1757918211679650262
   *
   * @return The interpolated value.
   */
  public static function smoothLerpPrecision(base:Float, target:Float, deltaTime:Float, duration:Float, precision:Float = 1 / 100):Float
  {
    if (deltaTime == 0) return base;
    if (base == target) return target;
    return lerp(target, base, Math.pow(precision, deltaTime / duration));
  }

  /**
   * Perform a framerate-independent linear interpolation between the base value and the target.
   * @param current The current value.
   * @param target The target value.
   * @param elapsed The time elapsed since the last frame.
   * @param duration The total duration of the interpolation. Nominal duration until remaining distance is less than `precision`.
   * @param precision The target precision of the interpolation. Defaults to 1% of distance remaining.
   * @see https://twitter.com/FreyaHolmer/status/1757918211679650262
   *
   * @return A value between the current value and the target value.
   * 
   * 
   * TODO: Test out the lerp above this one to determine if this one is worth keeping or not?
   */
  public static function smoothLerp(current:Float, target:Float, elapsed:Float, duration:Float, precision:Float = 1 / 100):Float
  {
    if (current == target) return target;

    var result:Float = lerp(current, target, 1 - Math.pow(precision, elapsed / duration));

    // TODO: Is there a better way to ensure a lerp which actually reaches the target?
    // Research a framerate-independent PID lerp.
    if (Math.abs(result - target) < (precision * target)) result = target;

    return result;
  }

  /**
   * Linearly interpolates a float that's framerate-independent. 
   * @param base The base value of the float.
   * @param target The current value.
   * @param ratio A normalized value to use for calculate the new float.
   * @return A value between the target, and base value.
   */
  public static function linearLerp(base:Float, target:Float, ratio:Float):Float 
  {
    return base + (ratio * (FlxG.elapsed / (1 / 60))) * (target - base);
  }
  
  /**
   * Specifically made to adapt lerps designed for 144 FPS to any framerate.
   * @param base The base value of the float.
   * @param target The current value.
   * @param ratio A normalized value to use for calculate the new float.
   * @param mult A multipler used while calculating the lerp. Defaults to '2.4'.
   * @return A value between the target, and base value that's framerate-independent.
   */
  public static function framerateLerp(base:Float, target:Float, ratio:Float, mult:Float = 2.4):Float 
  {
		return FlxMath.lerp(base, target, (FlxMath.bound((ratio * mult) * 60 * FlxG.elapsed, 0, 1)));
	}

  /**
   * Get the base-2 exponent of a value.
   * @param x value
   * @return `2^x`
   */
  public static function exp2(x:Float):Float
  {
    return Math.pow(2, x);
  }

  /**
   * Binds an interger value so that it doesn't go above, and below the specified values.
   * @param value The value to bound.
   * @param min The minimum value to bind 'value' from.
   * @param max The maximum value to bind 'value' from.
   * @return An interger bounded to the minimum and maximum value.
   */
  public static function limitInt(value:Int, min:Int, max:Int):Int 
  {
    return Std.int(FlxMath.bound(value, min, max));
  }

  /**
   * Binds a float value so that it doesn't go above, and below the specified values.
   * @param value The value to bound.
   * @param min The minimum value to bind 'value' from.
   * @param max The maximum value to bind 'value' from.
   * @return A real number bounded to the minimum and maximum value.
   */
  public static function limitFloat(value:Float, min:Float, max:Float):Float 
  {
    return FlxMath.bound(value, min, max);
  }

  
  /**
   * Binds a float value  so that in the case that it goes below or above its minimum or maximum value
   * it returns back to the maximum or the minimum value.
   * @param value Value to loop
   * @param min The minimum value to bind 'value' from.
   * @param max The maximum value to bind 'value' from.
   * @return An interger bounded according to its limits.
}
   */
  public static function loopInt(value:Int, min:Int, max:Int):Int 
  {
    return Std.int(loopFloat(value, min, max));
  }

  /**
   * Binds a real number so that in the case that it goes below or above its minimum or maximum value
   * it returns back to the maximum or the minimum value.
   * @param value Value to loop
   * @param min The minimum value to bind 'value' from.
   * @param max The maximum value to bind 'value' from.
   * @return A real number bounded according to its limits.
}
   */
  public static function loopFloat(value:Float, min:Float, max:Float):Float 
  {
    if (value > max) return min;
    if (value < min) return max;
    return value;
  }
}
