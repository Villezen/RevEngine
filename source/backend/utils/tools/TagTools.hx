package backend.utils.tools;

import flixel.FlxBasic;

/**
 * Implemented by engine objects which carry a string `tag`.
 */
interface ITaggable
{
    /**
     * A unique tag. Basically like `ID` but you can set it to any string.
     */
    var tag:String;
}

/**
 * Static extension for reading tags off plain flixel objects.
 */
class TagTools
{
    /**
     * Gets the `tag` of any object, or `""` if the object isn't taggable.
     */
    public static function getTag(basic:FlxBasic):String
    {
        if (basic is ITaggable)
        {
            var taggable:ITaggable = cast basic;
            return taggable.tag;
        }

        return "";
    }
}
