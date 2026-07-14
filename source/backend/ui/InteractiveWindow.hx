package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;

typedef InteractiveWindowParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var title:String;
    var items:Array<FunkinSprite>;
    var minimiziable:Bool;
    var callback:Bool->Void;
}

class InteractiveWindow extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;
    
    private function get_priority():Bool
    {
        if (params != null && params.items != null)
        {
            for (item in params.items)
            {
                if (Std.isOfType(item, IUiEntry) && (cast item:IUiEntry).priority)
                    return true;
            }
        }
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

    public var windowVisible(default, set):Bool = true;

    private function set_windowVisible(value:Bool):Bool
    {
        if (params.callback != null)
            params.callback(value);

        windowVisible = value;
        clickable = value;

        this.visible = value;
        this.active = value; 

        return value;
    }

    public var isMinimized(default, set):Bool = false;

    private function set_isMinimized(value:Bool):Bool
    {
        isMinimized = value;
        
        windowHitbox.visible = !value;
        bottomSolid.visible = value;
        
        for (slice in windowSliceMap)
            slice.visible = !value;

        if (params.items != null)
        {
            for (item in params.items)
            {
                item.visible = !value;
                item.active = !value; 
            }
        }
        
        return value;
    }

    private var isDragging:Bool = false;
    private var dragOffsetX:Float = 0;
    private var dragOffsetY:Float = 0;
    public var borderOffsetX:Int = 0;
    public var borderOffsetY:Int = 0;

    private var params:InteractiveWindowParams;

    private var windowHitbox:FunkinSprite;
    private var titleBarHitbox:FunkinSprite;
    private var windowTitle:FlxBitmapText;
    private var xButton:FunkinSprite;
    private var minimizeButton:FunkinSprite;
    private var bottomSolid:FunkinSprite;

    var windowSliceMap:Map<String, FunkinSprite> = [];
    var titleBarSliceMap:Map<String, FunkinSprite> = [];

    var windowAtlasFrames:FlxAtlasFrames;
    var titleBarAtlasFrames:FlxAtlasFrames;

    public function new(params:InteractiveWindowParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        titleBarAtlasFrames = Paths.getSparrowAtlas("engine/ui/titleBar"); 
        windowAtlasFrames = Paths.getSparrowAtlas("engine/ui/box_dark");

        var w:Int = (params != null && params.size != null) ? params.size[0] : 100;
        var h:Int = (params != null && params.size != null) ? params.size[1] : 50;
        var c:Int = 10;

        var tbH:Float = 30;
        var tbY:Float = -30; 

        titleBarHitbox = new FunkinSprite(0, tbY).makeGraphic(w, Std.int(tbH), FlxColor.TRANSPARENT);
        add(titleBarHitbox);

        windowHitbox = new FunkinSprite(0, 0).makeGraphic(w, h, FlxColor.TRANSPARENT);
        add(windowHitbox);

        titleBarSliceMap.set("tl", createSlice(0, tbY, "topleft", c, c, titleBarAtlasFrames));
        titleBarSliceMap.set("t",  createSlice(c, tbY, "top", w - (c * 2), c, titleBarAtlasFrames));
        titleBarSliceMap.set("tr", createSlice(w - c, tbY, "topright", c, c, titleBarAtlasFrames));

        titleBarSliceMap.set("ml", createSlice(0, tbY + c, "middleleft", c, tbH - (c * 2), titleBarAtlasFrames));
        titleBarSliceMap.set("m",  createSlice(c, tbY + c, "middle", w - (c * 2), tbH - (c * 2), titleBarAtlasFrames));
        titleBarSliceMap.set("mr", createSlice(w - c, tbY + c, "middleright", c, tbH - (c * 2), titleBarAtlasFrames));

        titleBarSliceMap.set("bl", createSlice(0, tbY + tbH - c, "bottomleft", c, c, titleBarAtlasFrames));
        titleBarSliceMap.set("b",  createSlice(c, tbY + tbH - c, "bottom", w - (c * 2), c, titleBarAtlasFrames));
        titleBarSliceMap.set("br", createSlice(w - c, tbY + tbH - c, "bottomright", c, c, titleBarAtlasFrames));

        windowSliceMap.set("tl", createSlice(0, 0, "topleft", c, c, windowAtlasFrames));
        windowSliceMap.set("t",  createSlice(c, 0, "top", w - (c * 2), c, windowAtlasFrames));
        windowSliceMap.set("tr", createSlice(w - c, 0, "topright", c, c, windowAtlasFrames));

        windowSliceMap.set("ml", createSlice(0, c, "middleleft", c, h - (c * 2), windowAtlasFrames));
        windowSliceMap.set("m",  createSlice(c, c, "middle", w - (c * 2), h - (c * 2), windowAtlasFrames));
        windowSliceMap.set("mr", createSlice(w - c, c, "middleright", c, h - (c * 2), windowAtlasFrames));

        windowSliceMap.set("bl", createSlice(0, h - c, "bottomleft", c, c, windowAtlasFrames));
        windowSliceMap.set("b",  createSlice(c, h - c, "bottom", w - (c * 2), c, windowAtlasFrames));
        windowSliceMap.set("br", createSlice(w - c, h - c, "bottomright", c, c, windowAtlasFrames));

        if (params.title != null)
        {
            var scaleFactor:Float = 0.3;
            windowTitle = new FlxBitmapText(0, 0, params.title, Paths.getAngelFont('jetbrains'));
            windowTitle.color = 0xFFFFFFFF;
            windowTitle.scale.set(scaleFactor, scaleFactor);
            windowTitle.updateHitbox();

            while (windowTitle.width > (w - c) && scaleFactor > 0.1)
            {
                scaleFactor -= 0.05;
                windowTitle.scale.set(scaleFactor, scaleFactor);
                windowTitle.updateHitbox();
            }

            windowTitle.setPosition(10, -22);
            add(windowTitle);
        }

        xButton = new FunkinSprite(0, 0).loadGraphic(Paths.image('engine/ui/windowButtons'), true, 50, 50);
        xButton.animation.add("anim", [0], 1, true);
        xButton.animation.play("anim", true);
        xButton.scale.set(0.4, 0.4);
        xButton.updateHitbox();
        xButton.setPosition(w - xButton.width - 10, tbY + 1 + (tbH - xButton.height) / 2);
        add(xButton);

        if (params.minimiziable)
        {
            minimizeButton = new FunkinSprite(0, 0).loadGraphic(Paths.image('engine/ui/windowButtons'), true, 50, 50);
            minimizeButton.animation.add("anim", [1], 1, true);
            minimizeButton.animation.play("anim", true);
            minimizeButton.scale.set(0.4, 0.4);
            minimizeButton.updateHitbox();
            minimizeButton.setPosition(w - minimizeButton.width - 40, tbY + 1 + (tbH - minimizeButton.height) / 2);
            add(minimizeButton);
        }

        if (params.items != null)
        {
            for (item in params.items)
            {
                add(item);
                if (Std.isOfType(item, IUiEntry))
                    UiManager.unregister(cast item);
            }
        }

        bottomSolid = new FunkinSprite(0, 0).makeGraphic(w, 3, FlxColor.BLACK);
        bottomSolid.visible = false;
        add(bottomSolid);

        if (params.callback != null)
            params.callback(windowVisible);
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float, targetFrames:FlxAtlasFrames):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = targetFrames;

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
        if (!visible) return null;
        if (isDragging) return this; 

        if (!isMinimized && params.items != null)
        {
            var i = params.items.length - 1;
            while (i >= 0)
            {
                var item = params.items[i];
                if (Std.isOfType(item, IUiEntry))
                {
                    var uiItem:IUiEntry = cast item;
                    var hovered = uiItem.getHoveredElement();

                    if (hovered != null)
                        return hovered;
                }
                i--;
            }
        }

        if (FlxG.mouse.overlaps(xButton)) return this;

        if (params.minimiziable)
            if (FlxG.mouse.overlaps(minimizeButton)) return this;

        if (FlxG.mouse.overlaps(titleBarHitbox)) return this;
        if (!isMinimized && FlxG.mouse.overlaps(windowHitbox)) return this;

        return null;
    }

    public function close()
    {
        windowVisible = false;
        isDragging = false;
    }

    public function open()
    {
        windowVisible = true;
        isDragging = false;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        var hasFocus = UiManager.hasFocus(this);

        if (hasFocus && FlxG.mouse.overlaps(xButton))
        {
            xButton.color = 0xFFCCCCCC;

            if (FlxG.mouse.justPressed)
                close();
        }
        else xButton.color = 0xFFFFFFFF;

        if (params.minimiziable)
        {
            if (hasFocus && FlxG.mouse.overlaps(minimizeButton))
            {
                minimizeButton.color = 0xFFCCCCCC;

                if (FlxG.mouse.justPressed)
                {
                    isMinimized = !isMinimized;
                    isDragging = false;

                    if (params.callback != null)
                        params.callback(false);
                }
            }
            else minimizeButton.color = 0xFFFFFFFF;
        }

        if (clickable)
        {
            if (FlxG.mouse.justPressed && hasFocus && FlxG.mouse.overlaps(titleBarHitbox))
            {
                isDragging = true;
                dragOffsetX = this.x - FlxG.mouse.x;
                dragOffsetY = this.y - FlxG.mouse.y;
            }

            if (FlxG.mouse.justReleased)
            {
                isDragging = false;
            }

            if (isDragging && FlxG.mouse.pressed)
            {
                this.x = FlxG.mouse.x + dragOffsetX;
                this.y = FlxG.mouse.y + dragOffsetY;

                if (this.x < 0 + borderOffsetX) 
                    this.x = 0 + borderOffsetX;
                if (this.x > FlxG.camera.width - windowHitbox.width) 
                    this.x = FlxG.camera.width - windowHitbox.width;

                if (this.y < 30 + borderOffsetY) 
                    this.y = 30 + borderOffsetY;
                
                var curHeight = isMinimized ? bottomSolid.height : windowHitbox.height;
                if (this.y > FlxG.camera.height - curHeight) 
                    this.y = FlxG.camera.height - curHeight;
            }
        }
    }
}