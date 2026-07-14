package backend.assets;

import flixel.text.FlxBitmapText;

import backend.utils.tools.TagTools.ITaggable;

/**
 * A FlxBitmapText with a settable `tag`.
 */
class FunkinBitmapText extends FlxBitmapText implements ITaggable
{
    public var tag:String = "";
}
