package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import openfl.display.BlendMode;

typedef SeparatorParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var alpha:Float;
    var color:Int;
    var blending:Bool;
}

class Separator extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;

    private function get_priority():Bool
    { 
        return _priority;
    }

    private function set_priority(value:Bool):Bool
    {
        _priority = value;
        return value;
    }

    public var clickable(default, set):Bool = false;

    private function set_clickable(value:Bool):Bool
    {
        clickable = value;
        return value;
    }

    private var params:SeparatorParams;

    var sliceMap:Map<String, FunkinSprite> = [];
    var atlasFrames:FlxAtlasFrames;

    public function new(params:SeparatorParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/separator"); 

        var w:Float = (params != null && params.size != null) ? params.size[0] : 100;
        var h:Float = (params != null && params.size != null) ? params.size[1] : 20;

        var cw:Float = Math.min(4.0, w / 2);
        var ch:Float = Math.min(4.0, h / 2);

        var midW:Float = w - (cw * 2);
        var midH:Float = h - (ch * 2);

        sliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch));
        sliceMap.set("t",  createSlice(cw, 0, "top", midW, ch));
        sliceMap.set("tr", createSlice(w - cw, 0, "topright", cw, ch));

        sliceMap.set("ml", createSlice(0, ch, "middleleft", cw, midH));
        sliceMap.set("m",  createSlice(cw, ch, "middle", midW, midH));
        sliceMap.set("mr", createSlice(w - cw, ch, "middleright", cw, midH));

        sliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch));
        sliceMap.set("b",  createSlice(cw, h - ch, "bottom", midW, ch));
        sliceMap.set("br", createSlice(w - cw, h - ch, "bottomright", cw, ch));
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;

        slice.animation.addByNames("idle", ["bar-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        
        if (targetW <= 0.01) targetW = 0.01;
        if (targetH <= 0.01) targetH = 0.01;

        slice.setGraphicSize(targetW, targetH);
        slice.updateHitbox();

        if (params != null)
        {
            slice.alpha = params.alpha;
            slice.color = params.color;
            slice.blend = BlendMode.OVERLAY;
        }

        add(slice);
        return slice;
    }

    public function getHoveredElement():IUiEntry
    {
        return null;
    }
}