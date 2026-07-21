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

    public static function compact():Void
    {
        #if cpp
        cpp.vm.Gc.compact();
        #else
        throw 'Not implemented!';
        #end
    }

    public static function freeUnusedMemory():Void
    {
        #if cpp
        cpp.vm.Gc.run(true);
        cpp.vm.Gc.compact();

        #if windows
        backend.platform.windows.WinAPI.emptyWorkingSet();
        #end

        _pressureBaseline = getGCUsage();
        _pressureTimer = 0.0;
        _sinceFullClean = 0.0;
        #end
    }

    static function collectOnly():Void
    {
        #if cpp
        cpp.vm.Gc.run(!(FlxG.state is game.PlayState));

        _pressureBaseline = getGCUsage();
        _pressureTimer = 0.0;
        #end
    }

    public static inline final PRESSURE_LIMIT:Float = 16 * 1024 * 1024;
    public static inline final IDLE_PRESSURE_LIMIT:Float = 8 * 1024 * 1024;

    public static inline final MAX_MEMORY_GROWTH:Float = 120;
    public static inline final MIN_MEMORY_GROWTH:Float = 2 * 1024 * 1024;

    static var _sinceFullClean:Float = 0.0;

    /**
     * Seconds between pressure checks.
     */
    static inline final PRESSURE_CHECK_INTERVAL:Float = 1.0;

    /**
     * Seconds after a state switch before the settle trim runs.
     */
    static inline final SETTLE_TRIM_DELAY:Float = 3.0;

    /**
     * GC usage recorded right after the last full cleanup, in bytes.
     */
    static var _pressureBaseline:Float = 0.0;

    /**
     * Internal timer for pressure checks, in seconds.
     */
    static var _pressureTimer:Float = 0.0;

    /**
     * Internal timer for the pending settle trim, in seconds.
     */
    static var _settleTimer:Float = 0.0;

    /**
     * Whether a settle trim is waiting to run.
     */
    static var _settlePending:Bool = false;

    /**
     * Whether the pressure watch has already started.
     */
    static var _watchStarted:Bool = false;

    /**
     * Gets the number of bytes currently in use by the GC.
     */
    public static function getGCUsage():Float
    {
        #if cpp
        return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
        #else
        return 0.0;
        #end
    }

    /**
     * Starts the memory pressure watch.
     */
    public static function startPressureWatch():Void
    {
        if (_watchStarted)
            return;

        _watchStarted = true;

        #if cpp
        _pressureBaseline = getGCUsage();

        FlxG.signals.postStateSwitch.add(() ->
        {
            _settlePending = true;
            _settleTimer = 0.0;
        });

        FlxG.signals.focusLost.add(() ->
        {
            if (canCleanNow() && !(FlxG.state is game.PlayState))
                freeUnusedMemory();
        });

        FlxG.signals.postUpdate.add(checkPressure);
        #end
    }

    /**
     * Whether a cleanup may run at all right now.
     */
    static function canCleanNow():Bool
    {
        if (FlxG.state == null)
            return false;

        if (backend.transition.TransitionState.switchingState)
            return false;

        if (FlxG.state.subState != null && (FlxG.state.subState is backend.transition.TransitionState))
            return false;

        return true;
    }

    static function checkPressure():Void
    {
        #if cpp
        _sinceFullClean += FlxG.elapsed;

        if (_settlePending)
        {
            _settleTimer += FlxG.elapsed;

            if (_settleTimer >= SETTLE_TRIM_DELAY && canCleanNow())
            {
                _settlePending = false;
                freeUnusedMemory();
            }
        }

        _pressureTimer += FlxG.elapsed;

        if (_pressureTimer < PRESSURE_CHECK_INTERVAL) return;

        _pressureTimer = 0.0;

        if (!canCleanNow()) return;

        var growth:Float = getGCUsage() - _pressureBaseline;

        if (FlxG.state is game.PlayState)
        {
            if (growth >= PRESSURE_LIMIT)
                collectOnly();

            return;
        }

        if (growth >= IDLE_PRESSURE_LIMIT || (_sinceFullClean >= MAX_MEMORY_GROWTH && growth >= MIN_MEMORY_GROWTH))
            freeUnusedMemory();

        #end
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