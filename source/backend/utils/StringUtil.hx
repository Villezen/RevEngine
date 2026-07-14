package backend.utils;

import flixel.math.FlxMath;

/**
 * Utilities for formatting different types of values
 */
class StringUtil
{
    /**
     * Formats a raw accuracy value to constantly have the two decimels visible. Used to prevent the score group being janky while centering.
     * @param value Accuracy value
     * @return Converted string
     */
    public static function formatAccuracy(value:Float):String
    {
        var rounded:Float = FlxMath.roundDecimal(value, 2);
        var str:String = (value < 10.0 ? "0" : "") + Std.string(rounded);
        
        var dotIndex:Int = str.indexOf(".");
        
        if (dotIndex == -1)
            return str + ".00";
        else if (str.length - dotIndex == 2)
            return str + "0";
        
        return str;
    }

    /**
     * Formats an array to use the crediting format.
     * @param array The array to convert.
     * @return Formatted string.
     */
    public static function formatCredits(array:Array<String>):String
    {
        if (array == null || array.length == 0) return "";
        if (array.length == 1) return array[0];
        if (array.length == 2) return array.join(" & ");
        
        var last:String = array[array.length - 1];
        var rest:Array<String> = array.slice(0, array.length - 1);
        
        return rest.join(", ") + " & " + last;
    }

    /**
     * Converts a string color to an actual FlxColor. 
     * @param str The string color value,
     * @return The converted color.
     */
    public static function convertColor(str:String):FlxColor
    {
        return FlxColor.fromString(str);
    }
}