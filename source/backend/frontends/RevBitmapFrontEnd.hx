package backend.frontends;

import flixel.system.frontEnds.BitmapFrontEnd;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets.FlxGraphicAsset;

import backend.assets.Cacher;

class RevBitmapFrontEnd extends BitmapFrontEnd
{
    override function add(graphic:FlxGraphicAsset, unique:Bool = false, ?key:String):FlxGraphic
    {
        var returnGraphic = super.add(graphic, unique, key);

        Cacher.instance.registerGraphic(returnGraphic);

        return returnGraphic;
    }

    override function create(width:Int, height:Int, color:FlxColor, unique:Bool = false, ?key:String):FlxGraphic
    {
        var returnGraphic = super.create(width, height, color, unique, key);

        Cacher.instance.registerGraphic(returnGraphic);

        return returnGraphic;
    }
}