package backend.utils;

import flixel.math.FlxMath;

/**
 * Utilities for working with the garbage collector.
 *
 * HXCPP is built on Immix.
 * HTML5 builds use the browser's built-in mark-and-sweep and JS has no APIs to interact with it.
 * @see https://www.cs.cornell.edu/courses/cs6120/2019fa/blog/immix/
 * @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Memory_management
 * @see https://betterprogramming.pub/deep-dive-into-garbage-collection-in-javascript-6881610239a
 * @see https://github.com/HaxeFoundation/hxcpp/blob/master/docs/build_xml/Defines.md
 * @see cpp.vm.Gc
 */
@:nullSafety
final class MemoryUtil
{
    /**
     * If the system can get the program's memory amount from its task.
     */
    public static function supportsTaskMem():Bool
    {
        #if ((cpp && (windows || ios || macos)) || linux || android)
        return true;
        #else
        return false;
        #end
    }

    /**
     * Gets the actual amount of memory the task of the program is using in MegaBytes.
     */
    public static function getTaskMemory():Float
    {
        var rawMemory:Float = 0.0;

        #if (windows && cpp)
        rawMemory = backend.platform.windows.WinAPI.getProcessMemoryWorkingSetSize();
        #elseif ((ios || macos) && cpp)
        rawMemory = backend.platform.apple.MemoryUtil.getCurrentProcessRss();
        #elseif (linux || android)
        try
        {
            #if cpp
            final input:sys.io.FileInput = sys.io.File.read('/proc/${cpp.NativeSys.sys_get_pid()}/status', false);
            #else
            final input:sys.io.FileInput = sys.io.File.read('/proc/self/status', false);
            #end

            final regex:EReg = ~/^VmRSS:\s+(\d+)\s+kB/m;
            var line:String;
            do
            {
                if (input.eof())
                {
                    input.close();
                    return 0.0;
                }
                line = input.readLine();
            }
            while (!regex.match(line));

            input.close();

            final kb:Float = Std.parseFloat(regex.matched(1));

            if (kb != Math.NaN)
            {
                rawMemory = kb * 1024.0;
            }
        }
        catch (e:Dynamic) {}
        #end

        return rawMemory;
    }

    /**
     * Get the memory amount reported by openfl's Garbage collector
     */
    public static function getGCMemory():Float
    {
        return openfl.system.System.totalMemoryNumber;
    }

    /**
     * Enable garbage collection if it was previously disabled.
     */
    public static function enable():Void
    {
        #if cpp
        cpp.vm.Gc.enable(true);
        #else
        throw 'Not implemented!';
        #end
    }

    /**
     * Disable garbage collection entirely.
     */
    public static function disable():Void
    {
        #if cpp
        cpp.vm.Gc.enable(false);
        #else
        throw 'Not implemented!';
        #end
    }

    /**
     * Manually perform garbage collection once.
     * Should only be called from the main thread.
     * @param major `true` to perform major collection, whatever that means.
     */
    public static function collect(major:Bool = false):Void
    {
        #if cpp
        cpp.vm.Gc.run(major);
        #else
        throw 'Not implemented!';
        #end
    }

    /**
     * Perform major garbage collection repeatedly until less than 16kb of memory is freed in one operation.
     * Should only be called from the main thread.
     *
     * NOTE: This is DIFFERENT from actual compaction,
     */
    public static function compact():Void
    {
        #if cpp
        cpp.vm.Gc.compact();
        #else
        throw 'Not implemented!';
        #end
    }

    /**
     * Frees the unused memory from the task.
     */
    public static function freeUnusedMemory():Void
    {
        #if cpp
        cpp.vm.Gc.run(true);
        cpp.vm.Gc.compact();

        #if windows
        backend.platform.windows.WinAPI.emptyWorkingSet();
        #end
        #end
    }

    /**
     * Lighter memory cleaning function that is safe to run during gameplay.
     */
    public static function softClean():Void
    {
        #if cpp
        cpp.vm.Gc.run(false);

        #if windows
        backend.platform.windows.WinAPI.emptyWorkingSet();
        #end
        #end
    }

    /**
     * Internal timer for periodic cleaning, in seconds.
     */
    static var _cleanTimer:Float = 0.0;

    /**
     * Whether periodic cleaning has already started.
     */
    static var _cleanStarted:Bool = false;

    /**
     * Softly cleans the memory after every given interval.
     */
    public static function startPeriodicCleaning():Void
    {
        if (_cleanStarted)
            return;
        
        _cleanStarted = true;

        FlxG.signals.preStateSwitch.add(() -> _cleanTimer = 0.0);
        FlxG.signals.postUpdate.add(periodicClean);
    }

    static function periodicClean():Void
    {
        if (Constants.IDLE_GC_INTERVAL <= 0) return;

        _cleanTimer += FlxG.elapsed;

        if (_cleanTimer < Constants.IDLE_GC_INTERVAL) return;

        _cleanTimer = 0.0;

        if ((FlxG.state is game.PlayState) || backend.transition.TransitionState.switchingState) return;

        softClean();
    }

    // Functions down below are used for the Memory Counter.

    /**
     * Rounds the memory amount, can also format the amount to be used as a gigabyte count.
     */
    public static function roundMemory(memValue:Float, roundToGB:Bool = true, roundToInt:Bool = false):Float
    {
        var megabytesMemory:Float = (Math.abs(FlxMath.roundDecimal(memValue / (1024 * 1024), 2)));

        if (roundToInt && megabytesMemory < 1024)
            return FlxMath.roundDecimal(megabytesMemory, 2);

        if (roundToGB && megabytesMemory >= 1024)
            return FlxMath.roundDecimal((megabytesMemory / 1024), 2);

        return megabytesMemory;
    }

    /**
     * What type of memory measurement to display based on the current @param memValue amount.
     * If the megabytes count equal or more than 1024, returns "GB", otherwise it will just display "MB"
     */
    public static function setMemoryUnitString(memValue:Float, rounded:Bool = true):String
    {
        var mem:Float = (!rounded ? roundMemory(memValue, false, false) : memValue*0.000001);
        return mem >= 1024 ? "GB" : "MB";
    }
}