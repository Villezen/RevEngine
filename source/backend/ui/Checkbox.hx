package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;

typedef CheckboxParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var callback:Bool->Void;
}

class Checkbox extends FlxSpriteGroup implements IUiEntry
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

    public var clickable(default, set):Bool = true;

    private function set_clickable(value:Bool):Bool
    {
        clickable = value;
        return value;
    }

    public var value(default, set):Bool = false;

    private function set_value(v:Bool):Bool
    {
        value = v;

        if (toggle != null) 
            toggle.alpha = value ? 1 : 0;

        return v;
    }

    private var params:CheckboxParams;
    private var hitbox:FunkinSprite;
    var toggle:FunkinSprite;
    var sliceMap:Map<String, FunkinSprite> = [];
    var label:FlxBitmapText;
    var currentState:String = "";
    var atlasFrames:FlxAtlasFrames;

    public function new(params:CheckboxParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);

        this.params = params;

        UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/checkbox"); 

        var w:Int = (params != null && params.size != null) ? params.size[0] : 100;
        var h:Int = (params != null && params.size != null) ? params.size[1] : 50;

        var c:Int = Std.int(Math.min(10, Math.min(w / 2, h / 2)));

        hitbox = new FunkinSprite(0, 0).makeGraphic(w, h, FlxColor.TRANSPARENT);
        add(hitbox);

        sliceMap.set("tl", createSlice(0, 0, "topleft", c, c));
        sliceMap.set("t",  createSlice(c, 0, "top", w - (c * 2), c));
        sliceMap.set("tr", createSlice(w - c, 0, "topright", c, c));

        sliceMap.set("ml", createSlice(0, c, "middleleft", c, h - (c * 2)));
        sliceMap.set("m",  createSlice(c, c, "middle", w - (c * 2), h - (c * 2)));
        sliceMap.set("mr", createSlice(w - c, c, "middleright", c, h - (c * 2)));

        sliceMap.set("bl", createSlice(0, h - c, "bottomleft", c, c));
        sliceMap.set("b",  createSlice(c, h - c, "bottom", w - (c * 2), c));
        sliceMap.set("br", createSlice(w - c, h - c, "bottomright", c, c));

        toggle = new FunkinSprite().loadGraphic(Paths.image('engine/ui/checkboxToggle'));
        toggle.setGraphicSize(w / 2, h / 2);
        toggle.updateHitbox();
        toggle.setPosition((w - toggle.width) / 2, (h - toggle.height) / 2);
        toggle.antialiasing = true;
        toggle.alpha = value ? 1 : 0;
        add(toggle);
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;

        slice.animation.addByNames("idle", ["box-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        slice.setGraphicSize(Std.int(targetW), Std.int(targetH));
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable) return null;
        if (FlxG.mouse.overlaps(hitbox)) return this;
        return null;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (clickable && UiManager.hasFocus(this))
        {
            if (FlxG.mouse.pressed)
            {
                for (slice in sliceMap)
                    slice.color = 0xFF969696;
                toggle.color = 0xFF828282;
            }
            else
            {
                for (slice in sliceMap)
                    slice.color = 0xFFBFBFBF;
                toggle.color = 0xFFB7B7B7;

                if (FlxG.mouse.justReleased)
                {
                    this.value = !value;
                    
                    if (params != null && params.callback != null)
                        params.callback(value);
                }
            }
        }
        else
        {
            for (slice in sliceMap)
                slice.color = 0xFFFFFFFF;

            toggle.color = 0xFFFFFFFF;
        }
    }
}