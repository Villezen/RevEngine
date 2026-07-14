package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import backend.utils.MathUtil;

typedef SliderParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var values:SliderValues;
    var callback:Float->Void;
}

typedef SliderValues =
{
    var min:Float;
    var max:Float;
}

class Slider extends FlxSpriteGroup implements IUiEntry
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

    private var isDragging:Bool = false;
    private var dragOffsetX:Float = 0;

    public var clickable(default, set):Bool = true;

    private function set_clickable(value:Bool):Bool
    {
        clickable = value;

        if (!clickable)
            isDragging = false;

        return value;
    }

    private var oldValue:Float = 0.0;
    public var value(default, set):Float = 0.0;

    private function set_value(newValue:Float):Float
    {
        if (thumbHitbox == null || params == null) 
        {
            value = newValue;
            return value;
        }

        var clampedValue:Float = newValue;
        if (clampedValue < params.values.min) clampedValue = params.values.min;
        if (clampedValue > params.values.max) clampedValue = params.values.max;

        value = clampedValue;

        var minX:Float = this.x - (thumbHitbox.width / 2);
        var maxX:Float = (this.x + params.size[0]) - (thumbHitbox.width / 2);

        var targetX:Float = FlxMath.remapToRange(value, params.values.min, params.values.max, minX, maxX);

        thumbHitbox.x = targetX;
        thumb.x = targetX;
        updateFillBar();

        if (params.callback != null && oldValue != value)
        {
            params.callback(value);
            oldValue = value;
        }

        return value;
    }

    private var params:SliderParams;

    private var barHitbox:FunkinSprite;
    private var thumbHitbox:FunkinSprite;

    var sliceMap:Map<String, FunkinSprite> = [];
    var fullSliceMap:Map<String, FunkinSprite> = [];

    private var thumbScale:Float = 1.0;
    var thumb:FunkinSprite;

    var atlasFrames:FlxAtlasFrames;
    var atlasFramesFull:FlxAtlasFrames;

    public function new(params:SliderParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;

        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        if (this.params.values == null)
            this.params.values = {min: 0.0, max: 1.0};

        var w:Float = (params.size != null) ? params.size[0] : 100;
        var h:Float = (params.size != null) ? params.size[1] : 20;

        var cw:Float = Math.min(8.0, w / 2);
        var ch:Float = Math.min(8.0, h / 2);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/slider");
        atlasFramesFull = Paths.getSparrowAtlas("engine/ui/slider_full");

        barHitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(w), Std.int(h), FlxColor.TRANSPARENT);
        add(barHitbox);

        sliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch, atlasFrames));
        sliceMap.set("t",  createSlice(cw, 0, "top", w - (cw * 2), ch, atlasFrames));
        sliceMap.set("tr", createSlice(w - cw, 0, "topright", cw, ch, atlasFrames));

        sliceMap.set("ml", createSlice(0, ch, "middleleft", cw, h - (ch * 2), atlasFrames));
        sliceMap.set("m",  createSlice(cw, ch, "middle", w - (cw * 2), h - (ch * 2), atlasFrames));
        sliceMap.set("mr", createSlice(w - cw, ch, "middleright", cw, h - (ch * 2), atlasFrames));

        sliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch, atlasFrames));
        sliceMap.set("b",  createSlice(cw, h - ch, "bottom", w - (cw * 2), ch, atlasFrames));
        sliceMap.set("br", createSlice(w - cw, h - ch, "bottomright", cw, ch, atlasFrames));

        fullSliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch, atlasFramesFull));
        fullSliceMap.set("t",  createSlice(cw, 0, "top", w - (cw * 2), ch, atlasFramesFull));
        fullSliceMap.set("tr", createSlice(w - cw, 0, "topright", cw, ch, atlasFramesFull));

        fullSliceMap.set("ml", createSlice(0, ch, "middleleft", cw, h - (ch * 2), atlasFramesFull));
        fullSliceMap.set("m",  createSlice(cw, ch, "middle", w - (cw * 2), h - (ch * 2), atlasFramesFull));
        fullSliceMap.set("mr", createSlice(w - cw, ch, "middleright", cw, h - (ch * 2), atlasFramesFull));

        fullSliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch, atlasFramesFull));
        fullSliceMap.set("b",  createSlice(cw, h - ch, "bottom", w - (cw * 2), ch, atlasFramesFull));
        fullSliceMap.set("br", createSlice(w - cw, h - ch, "bottomright", cw, ch, atlasFramesFull));

        thumbHitbox = new FunkinSprite(-((h + 20) / 2), -10).makeGraphic(Std.int(h + 20), Std.int(h + 20), FlxColor.TRANSPARENT);
        add(thumbHitbox);

        thumb = new FunkinSprite(thumbHitbox.x, thumbHitbox.y).loadGraphic(Paths.image("engine/ui/sliderThumb"));
        thumb.setGraphicSize(Std.int(thumbHitbox.width), Std.int(thumbHitbox.height));
        thumb.updateHitbox();
        thumbScale = thumb.scale.x;
        add(thumb);

        this.value = this.params.values.min;
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float, targetFrames:FlxAtlasFrames):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = targetFrames; 

        slice.animation.addByNames("idle", ["slider-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        slice.setGraphicSize(Std.int(targetW), Std.int(targetH));
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible) return null;
        if (isDragging) return this;
        if (!clickable) return null;
        if (FlxG.mouse.overlaps(thumbHitbox) || FlxG.mouse.overlaps(barHitbox)) return this;
        return null;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        var hasFocus = UiManager.hasFocus(this);

        if (clickable)
        {
            if (FlxG.mouse.justPressed && hasFocus && FlxG.mouse.overlaps(thumbHitbox))
            {
                isDragging = true;
                dragOffsetX = thumbHitbox.x - FlxG.mouse.x; 
            }
            else if (FlxG.mouse.justReleased && isDragging)
            {
                isDragging = false;
            }
        }

        var targetScale:Float = thumbScale;

        if (clickable)
        {
            if (isDragging) 
                targetScale = thumbScale + 0.07;
            else if (hasFocus && FlxG.mouse.overlaps(thumbHitbox)) 
                targetScale = thumbScale + 0.03;
        }

        thumb.scale.x = MathUtil.smoothLerpPrecision(thumb.scale.x, targetScale, elapsed, 0.1);
        thumb.scale.y = MathUtil.smoothLerpPrecision(thumb.scale.y, targetScale, elapsed, 0.1);

        if (isDragging)
        {
            var minX:Float = this.x - (thumbHitbox.width / 2);
            var maxX:Float = (this.x + params.size[0]) - (thumbHitbox.width / 2);

            var targetX:Float = FlxG.mouse.x + dragOffsetX;

            if (targetX < minX) targetX = minX;
            if (targetX > maxX) targetX = maxX;

            thumbHitbox.x = targetX;
            thumb.x = targetX;

            value = FlxMath.remapToRange(targetX, minX, maxX, params.values.min, params.values.max);

            if (params.callback != null && oldValue != value)
            {
                params.callback(value);
                oldValue = value;
            }
        }

        updateFillBar();
    }

    private function updateFillBar():Void
    {
        var w:Float = (params.size != null) ? params.size[0] : 100;
        var h:Float = (params.size != null) ? params.size[1] : 20;

        var cw:Float = Math.min(8.0, w / 2);
        var ch:Float = Math.min(8.0, h / 2);

        var fillW:Float = (thumbHitbox.x + (thumbHitbox.width / 2)) - this.x;

        if (fillW < 0) fillW = 0;
        if (fillW > w) fillW = w;

        if (fillW <= 0.1)
        {
            for (slice in fullSliceMap) slice.visible = false;
            return;
        }

        for (slice in fullSliceMap) slice.visible = true;

        var t = fullSliceMap.get("t");
        var m = fullSliceMap.get("m");
        var b = fullSliceMap.get("b");
        
        var tl = fullSliceMap.get("tl");
        var ml = fullSliceMap.get("ml");
        var bl = fullSliceMap.get("bl");
        
        var tr = fullSliceMap.get("tr");
        var mr = fullSliceMap.get("mr");
        var br = fullSliceMap.get("br");

        var centerW:Float = fillW - (cw * 2);

        if (centerW <= 0.1)
        {
            t.visible = false;
            m.visible = false;
            b.visible = false;

            var halfSafe:Float = fillW / 2;

            if (halfSafe < 0.1)
                halfSafe = 0.1;

            tl.setGraphicSize(halfSafe, ch);
            ml.setGraphicSize(halfSafe, h - (ch * 2));
            bl.setGraphicSize(halfSafe, ch);

            tr.setGraphicSize(halfSafe, ch);
            mr.setGraphicSize(halfSafe, h - (ch * 2));
            br.setGraphicSize(halfSafe, ch);

            var rightX:Float = this.x + halfSafe;
            tr.x = rightX;
            mr.x = rightX;
            br.x = rightX;
        }
        else
        {
            tl.setGraphicSize(cw, ch);
            ml.setGraphicSize(cw, h - (ch * 2));
            bl.setGraphicSize(cw, ch);

            tr.setGraphicSize(cw, ch);
            mr.setGraphicSize(cw, h - (ch * 2));
            br.setGraphicSize(cw, ch);

            t.setGraphicSize(centerW, ch);
            m.setGraphicSize(centerW, h - (ch * 2));
            b.setGraphicSize(centerW, ch);

            var rightX:Float = this.x + fillW - cw;
            tr.x = rightX;
            mr.x = rightX;
            br.x = rightX;
        }

        for (slice in fullSliceMap)
        {
            if (slice.visible)
                slice.updateHitbox();
        }
    }
}