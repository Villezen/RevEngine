package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;

typedef StepperParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var type:String;
    var args:Array<Dynamic>;
    var callback:Dynamic->Void;
}

class Stepper extends FlxSpriteGroup implements IUiEntry
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

    private var params:StepperParams;

    private var leftHitbox:FunkinSprite;
    private var rightHitbox:FunkinSprite;
    private var middleHitbox:FunkinSprite;

    private var leftArrow:FunkinSprite;
    private var rightArrow:FunkinSprite;

    var leftSliceMap:Map<String, FunkinSprite> = [];
    var middleSliceMap:Map<String, FunkinSprite> = [];
    var rightSliceMap:Map<String, FunkinSprite> = [];

    var atlasFrames:FlxAtlasFrames;

    public var currentValue:Dynamic;
    private var currentIndex:Int = 0;
    private var label:FlxBitmapText;

    private var leftHovered:Bool = false;
    private var rightHovered:Bool = false;

    private var holdTimer:Float = 0;
    private var holdDirection:Int = 0;
    private var holdDelay:Float = 0.5;
    private var rapidRate:Float = 0.05;

    public function new(params:StepperParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/stepper"); 

        var w:Float = (params != null && params.size != null) ? params.size[0] : 150;
        var h:Float = (params != null && params.size != null) ? params.size[1] : 30;

        var scale:Float = h / 100.0;
        var widenFactor:Float = 1.4; 
        
        var btnW:Float = 37.0 * scale * widenFactor;
        var midW:Float = w - (btnW * 2);

        var minMidW:Float = 50.0 * scale;
        if (midW < minMidW)
            midW = minMidW;

        var sideCW:Float = 15 * scale;
        var sideMidW:Float = btnW - (sideCW * 2);
        if (sideMidW < 0.1) sideMidW = 0.1;

        leftSliceMap.set("tl", createSlice(0, 0, "left-topleft", sideCW, 15 * scale));
        leftSliceMap.set("t",  createSlice(sideCW, 0, "left-top", sideMidW, 15 * scale));
        leftSliceMap.set("tr", createSlice(sideCW + sideMidW, 0, "left-topright", sideCW, 15 * scale));

        leftSliceMap.set("ml", createSlice(0, 15 * scale, "left-middleleft", sideCW, 70 * scale));
        leftSliceMap.set("m",  createSlice(sideCW, 15 * scale, "left-middle", sideMidW, 70 * scale));
        leftSliceMap.set("mr", createSlice(sideCW + sideMidW, 15 * scale, "left-middleright", sideCW, 70 * scale));

        leftSliceMap.set("bl", createSlice(0, 85 * scale, "left-bottomleft", sideCW, 15 * scale));
        leftSliceMap.set("b",  createSlice(sideCW, 85 * scale, "left-bottom", sideMidW, 15 * scale));
        leftSliceMap.set("br", createSlice(sideCW + sideMidW, 85 * scale, "left-bottomright", sideCW, 15 * scale));

        var boxCW = 25 * scale;
        var boxMidW = midW - (boxCW * 2);

        middleSliceMap.set("tl", createSlice(btnW, 0, "box-topleft", boxCW, boxCW));
        middleSliceMap.set("t",  createSlice(btnW + boxCW, 0, "box-top", boxMidW, boxCW));
        middleSliceMap.set("tr", createSlice(btnW + boxCW + boxMidW, 0, "box-topright", boxCW, boxCW));

        middleSliceMap.set("ml", createSlice(btnW, boxCW, "box-middleleft", boxCW, 50 * scale));
        middleSliceMap.set("m",  createSlice(btnW + boxCW, boxCW, "box-middle", boxMidW, 50 * scale));
        middleSliceMap.set("mr", createSlice(btnW + boxCW + boxMidW, boxCW, "box-middleright", boxCW, 50 * scale));

        middleSliceMap.set("bl", createSlice(btnW, 75 * scale, "box-bottomleft", boxCW, boxCW));
        middleSliceMap.set("b",  createSlice(btnW + boxCW, 75 * scale, "box-bottom", boxMidW, boxCW));
        middleSliceMap.set("br", createSlice(btnW + boxCW + boxMidW, 75 * scale, "box-bottomright", boxCW, boxCW));

        var rX = btnW + midW;
        rightSliceMap.set("tl", createSlice(rX, 0, "right-topleft", sideCW, 15 * scale));
        rightSliceMap.set("t",  createSlice(rX + sideCW, 0, "right-top", sideMidW, 15 * scale));
        rightSliceMap.set("tr", createSlice(rX + sideCW + sideMidW, 0, "right-topright", sideCW, 15 * scale));

        rightSliceMap.set("ml", createSlice(rX, 15 * scale, "right-middleleft", sideCW, 70 * scale));
        rightSliceMap.set("m",  createSlice(rX + sideCW, 15 * scale, "right-middle", sideMidW, 70 * scale));
        rightSliceMap.set("mr", createSlice(rX + sideCW + sideMidW, 15 * scale, "right-middleright", sideCW, 70 * scale));

        rightSliceMap.set("bl", createSlice(rX, 85 * scale, "right-bottomleft", sideCW, 15 * scale));
        rightSliceMap.set("b",  createSlice(rX + sideCW, 85 * scale, "right-bottom", sideMidW, 15 * scale));
        rightSliceMap.set("br", createSlice(rX + sideCW + sideMidW, 85 * scale, "right-bottomright", sideCW, 15 * scale));

        label = new FlxBitmapText(0, 0, "0", Paths.getAngelFont('jetbrains'));
        label.color = 0xFFFFFFFF;
        label.scale.set(0.37, 0.37);
        label.updateHitbox();
        add(label);

        var padding:Float = 16.0 * scale;
        var maxArrowW:Float = btnW - (padding * 2);
        var maxArrowH:Float = h - (padding * 2);

        leftArrow = new FunkinSprite().loadGraphic(Paths.image('engine/ui/stepperArrow'));
        var arrowScaleX:Float = maxArrowW / leftArrow.width;
        var arrowScaleY:Float = maxArrowH / leftArrow.height;
        var arrowScale:Float = Math.min(arrowScaleX, arrowScaleY);

        leftArrow.setGraphicSize(Std.int(leftArrow.width * arrowScale), Std.int(leftArrow.height * arrowScale));
        leftArrow.updateHitbox(); 
        leftArrow.x = ((btnW - leftArrow.width) / 2) + 1;
        leftArrow.y = (h - leftArrow.height) / 2;
        leftArrow.antialiasing = true;
        add(leftArrow);

        rightArrow = new FunkinSprite().loadGraphic(Paths.image('engine/ui/stepperArrow'));
        rightArrow.setGraphicSize(Std.int(rightArrow.width * arrowScale), Std.int(rightArrow.height * arrowScale));
        rightArrow.updateHitbox();
        rightArrow.flipX = true;
        rightArrow.x = (rX + (btnW - rightArrow.width) / 2) - 1;
        rightArrow.y = (h - rightArrow.height) / 2;
        rightArrow.antialiasing = true;
        add(rightArrow);

        leftHitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(btnW), Std.int(h), FlxColor.TRANSPARENT);
        add(leftHitbox);

        middleHitbox = new FunkinSprite(btnW, 0).makeGraphic(Std.int(midW), Std.int(h), FlxColor.TRANSPARENT);
        add(middleHitbox);

        rightHitbox = new FunkinSprite(rX, 0).makeGraphic(Std.int(btnW), Std.int(h), FlxColor.TRANSPARENT);
        add(rightHitbox);

        initValue();
        updateLabel();
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;

        slice.animation.addByNames("idle", [sliceName], 1, false);
        slice.animation.play("idle");
        slice.origin.set(0, 0);
        
        if (targetW <= 0.1) targetW = 0.1;
        if (targetH <= 0.1) targetH = 0.1;

        slice.setGraphicSize(targetW, targetH);
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    private function initValue()
    {
        if (params == null || params.args == null || params.args.length == 0) return;

        if (params.type == "String")
        {
            currentIndex = 0;
            currentValue = params.args[0];
        } else
            currentValue = params.args[0];
    }

    public function setValue(v:Dynamic)
    {
        if (params == null) return;

        if (params.type == "String")
        {
            if (params.args != null)
            {
                var idx:Int = params.args.indexOf(v);
                if (idx >= 0) currentIndex = idx;
            }

            currentValue = v;
        }
        else if (params.type == "Int")
        {
            var val:Int = Std.int(v);

            if (params.args != null && params.args.length >= 2)
            {
                if (val < Std.int(params.args[0])) val = Std.int(params.args[0]);
                if (val > Std.int(params.args[1])) val = Std.int(params.args[1]);
            }

            currentValue = val;
        }
        else
        {
            var val:Float = v;

            if (params.args != null && params.args.length >= 2)
            {
                if (val < params.args[0]) val = params.args[0];
                if (val > params.args[1]) val = params.args[1];
            }

            currentValue = val;
        }

        updateLabel();
    }

    private function updateLabel()
    {
        var displayStr:String = "";
        displayStr = Std.string(currentValue);

        label.text = displayStr;
        
        var scaleFactor:Float = 0.4;
        label.scale.set(scaleFactor, scaleFactor);
        label.updateHitbox();

        if (middleHitbox != null)
        {
            var textPadding:Float = 5.0;
            var maxTextWidth:Float = middleHitbox.width - (textPadding * 2);

            while (label.width > maxTextWidth && scaleFactor > 0.1)
            {
                scaleFactor -= 0.05;
                label.scale.set(scaleFactor, scaleFactor);
                label.updateHitbox();
            }

            label.x = middleHitbox.x + (middleHitbox.width - label.width) / 2;
            label.y = middleHitbox.y + 2 + (middleHitbox.height - label.height) / 2;
        }
    }

    private function stepValue(direction:Int)
    {
        if (params == null || params.args == null) return;

        if (params.type == "String")
        {
            currentIndex += direction;

            if (currentIndex < 0)
                currentIndex = params.args.length - 1;
            if (currentIndex >= params.args.length)
                currentIndex = 0;

            currentValue = params.args[currentIndex];
        }
        else
        {
            var min:Float = params.args[0];
            var max:Float = params.args[1];
            var step:Float = params.args.length > 2 ? params.args[2] : 1;

            if (params.type == "Int")
            {
                var val:Int = cast currentValue;
                val += Std.int(step * direction);
                if (val < Std.int(min)) val = Std.int(min);
                if (val > Std.int(max)) val = Std.int(max);
                currentValue = val;
            }
            else if (params.type == "Float")
            {
                var val:Float = cast currentValue;
                val += step * direction;
                if (val < min) val = min;
                if (val > max) val = max;
                currentValue = val;
            }
        }

        updateLabel();
        if (params.callback != null) params.callback(currentValue);
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable) return null;
        if (leftHitbox != null && FlxG.mouse.overlaps(leftHitbox)) return this;
        if (rightHitbox != null && FlxG.mouse.overlaps(rightHitbox)) return this;
        if (middleHitbox != null && FlxG.mouse.overlaps(middleHitbox)) return this;
        return null;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        leftHovered = false;
        rightHovered = false;

        if (clickable && UiManager.hasFocus(this))
        {
            if (FlxG.mouse.overlaps(leftHitbox)) leftHovered = true;
            if (FlxG.mouse.overlaps(rightHitbox)) rightHovered = true;

            if (FlxG.mouse.justPressed)
            {
                if (leftHovered)
                {
                    stepValue(-1);
                    holdDirection = -1;
                    holdTimer = 0;
                }
                else if (rightHovered)
                {
                    stepValue(1);
                    holdDirection = 1;
                    holdTimer = 0;
                }
            }
        }

        if (FlxG.mouse.pressed && holdDirection != 0)
        {
            if ((holdDirection == -1 && leftHovered) || (holdDirection == 1 && rightHovered))
            {
                holdTimer += elapsed;

                while (holdTimer >= holdDelay)
                {
                    stepValue(holdDirection);
                    holdTimer -= rapidRate; 
                }
            }
            else
                holdDirection = 0;
        }
        else if (FlxG.mouse.justReleased)
            holdDirection = 0;

        var leftColor:FlxColor = leftHovered ? 0xFFCCCCCC : 0xFFFFFFFF;
        for (slice in leftSliceMap) slice.color = leftColor;
        leftArrow.color = leftColor;

        var rightColor:FlxColor = rightHovered ? 0xFFCCCCCC : 0xFFFFFFFF;
        for (slice in rightSliceMap) slice.color = rightColor;
        rightArrow.color = rightColor;
    }
}