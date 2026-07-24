package backend.utils;

import flixel.input.keyboard.FlxKey;

class KeyUtil
{
    /**
     * Gets the scale multiplier of strumline objects depending on the key amount. Used to not make strums go off screen.
     * @param keyCount The amount of keys on the strumline.
     * @return Scale multiplier.
     */
    public static function getKeyScaleOffset(keyCount:Int):Float 
    {
        var targetScale:Float = 1.0;

        if (keyCount > 4)
        {
            var defaultScale:Float = 4.0 / keyCount;
            targetScale = defaultScale + (1.0 - defaultScale) * 0.2;
        }

        return targetScale;
    }

    /**
     * Checks if the class should load the "-multikey" variant of a skin.
     * @param keyCount The key amount.
     * @return Should it use the "-multikey" variant?
     */
    public static function isMultiKey(keys:Int):Bool
    {
        return (keys > 4 || [3, 1].contains(keys));
    }

    public static function formatNoteBind(input:String, keyCount:Int):String
    {
        var regex:EReg = ~/keybind\[(\d+)\]/g;

        if (!regex.match(input))
            return input;

        return regex.map(input, function(e:EReg):String 
        {
            var dir:Int = Std.parseInt(e.matched(1));
            var fieldName:String = "NOTE_BINDS_" + keyCount + "K";
            var bindsArray:Array<Array<FlxKey>> = Reflect.field(Configs, fieldName);

            if (keyCount == 2 && dir == 3)
                dir = 1;

            if (bindsArray != null && dir >= 0 && dir < bindsArray.length)
            {
                var keyCode:FlxKey = bindsArray[dir][0];

                if (keyCode != FlxKey.NONE)
                {
                    var keyName:String = Std.string(keyCode);
                    return keyName; 
                }
            }

            return "A"; 
        }); 
    }
}