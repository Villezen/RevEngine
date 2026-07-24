package backend.ui;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;

typedef ButtonParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var text:String;
    var callback:() -> Void;
}

class Button extends FlxSpriteGroup implements IUiEntry
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

    private var params:ButtonParams;
    private var hitbox:FunkinSprite;

    var sliceMap:Map<String, FunkinSprite> = [];
    var label:FlxBitmapText;
    var currentState:String = "";
    var atlasFrames:FlxAtlasFrames;

    public function new(params:ButtonParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/button"); 

        var w:Int = (params != null && params.size != null) ? params.size[0] : 100;
        var h:Int = (params != null && params.size != null) ? params.size[1] : 50;
        var c:Int = 10;

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

        if (params != null && params.text != null && params.text != "")
        {
            var scaleFactor:Float = 0.4;
            label = new FlxBitmapText(0, 0, params.text, Paths.getAngelFont('jetbrains'));
            label.color = 0xFFFFFFFF;
            label.scale.set(scaleFactor, scaleFactor);
            label.updateHitbox();

            while (label.width > (w - c) && scaleFactor > 0.1)
            {
                scaleFactor -= 0.05;
                label.scale.set(scaleFactor, scaleFactor);
                label.updateHitbox();
            }

            label.setPosition((w - label.width) / 2, ((h - label.height) / 2) + 2);
            add(label);
        }

        changeState("idle");
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;

        slice.animation.addByNames("idle", ["idle-" + sliceName], 1, false);
        slice.animation.addByNames("hover", ["hover-" + sliceName], 1, false);
        slice.animation.addByNames("click", ["click-" + sliceName], 1, false);

        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        slice.setGraphicSize(Std.int(targetW), Std.int(targetH));
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    private function changeState(state:String)
    {
        if (currentState == state) return;
        currentState = state;

        for (slice in sliceMap)
            slice.animation.play(state);
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
                changeState("click");
            }
            else
            {
                changeState("hover");
                if (FlxG.mouse.justReleased && params != null && params.callback != null)
                    params.callback();
            }
        }
        else
        {
            changeState("idle");
        }
    }

    override public function destroy()
    {
        UiManager.unregister(this);
        
        super.destroy();
    }
}