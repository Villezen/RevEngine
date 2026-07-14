package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import backend.utils.MathUtil;

typedef ContextMenuParams =
{
    var position:Array<Int>;
    var width:Int;
    var items:Array<ContextMenuItem>;
}

typedef ContextMenuItem =
{
    var text:String;
    var altText:String;
    var separate:Bool;
    var callback:() -> Void;
}

class ContextMenu extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = true;

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

        for (item in itemMap)
            item.clickable = value;

        return value;
    }

    private var params:ContextMenuParams;
    private var hitbox:FunkinSprite;

    var sliceMap:Map<String, FunkinSprite> = [];
    var itemMap:Map<String, Item> = [];

    var atlasFrames:FlxAtlasFrames;

    public var targetAlpha:Float = 0.0;

    public function new(params:ContextMenuParams)
    {
        super();
        this.params = (params != null) ? params : {position: [0, 0], width: 100, items: []};

        UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/box");

        var h:Float = 100;
        var cw:Float = Math.min(10.0, params.width / 2);
        var ch:Float = Math.min(10.0, h / 2);

        hitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(params.width), Std.int(h), FlxColor.TRANSPARENT);
        add(hitbox);

        sliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch));
        sliceMap.set("t",  createSlice(cw, 0, "top", params.width - (cw * 2), ch));
        sliceMap.set("tr", createSlice(params.width - cw, 0, "topright", cw, ch));

        sliceMap.set("ml", createSlice(0, ch, "middleleft", cw, h - (ch * 2)));
        sliceMap.set("m",  createSlice(cw, ch, "middle", params.width - (cw * 2), h - (ch * 2)));
        sliceMap.set("mr", createSlice(params.width - cw, ch, "middleright", cw, h - (ch * 2)));

        sliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch));
        sliceMap.set("b",  createSlice(cw, h - ch, "bottom", params.width - (cw * 2), ch));
        sliceMap.set("br", createSlice(params.width - cw, h - ch, "bottomright", cw, ch));

        sync();
        reload();
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;
        slice.alpha = 0;

        slice.animation.addByNames("idle", ["box-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        slice.setGraphicSize(Std.int(targetW), Std.int(targetH));
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    public function show():Void
    {
        targetAlpha = 1;
    }

    public function hide():Void
    {
        targetAlpha = 0;
    }

    public function sync():Void
    {
        if (params.position == null)
            this.setPosition(FlxG.mouse.x, FlxG.mouse.y);
        else
            this.setPosition(params.position[0], params.position[1]);
    }

    public function reload(?items:Array<ContextMenuItem>)
    {
        var activeItems:Array<ContextMenuItem> = items;

        if (activeItems == null && params != null) activeItems = params.items;
        if (activeItems == null) activeItems = [];

        for (item in itemMap)
        {
            remove(item, true);
            item.destroy();
        }
        itemMap.clear();

        var currentY:Float = 10;

        for (i in 0...activeItems.length)
        {
            var itemData = activeItems[i];

            var item = new Item(0, Std.int(currentY), params.width, itemData, this);
            item.clickable = this.clickable;
            add(item);
            
            itemMap.set(i + "_" + itemData.text, item);

            currentY += itemData.separate ? 35 : 30;
        }

        currentY += 10; 

        var newH:Float = currentY;

        var cw:Float = Math.min(10.0, params.width / 2);
        var ch:Float = Math.min(10.0, newH / 2);

        hitbox.setGraphicSize(Std.int(params.width), Std.int(newH));
        hitbox.updateHitbox();

        updateSlice("tl", 0, 0, cw, ch);
        updateSlice("t",  cw, 0, params.width - (cw * 2), ch);
        updateSlice("tr", params.width - cw, 0, cw, ch);

        updateSlice("ml", 0, ch, cw, newH - (ch * 2));
        updateSlice("m",  cw, ch, params.width - (cw * 2), newH - (ch * 2));
        updateSlice("mr", params.width - cw, ch, cw, newH - (ch * 2));

        updateSlice("bl", 0, newH - ch, cw, ch);
        updateSlice("b",  cw, newH - ch, params.width - (cw * 2), ch);
        updateSlice("br", params.width - cw, newH - ch, cw, ch);
    }

    private function updateSlice(id:String, xLocal:Float, yLocal:Float, targetW:Float, targetH:Float)
    {
        var slice = sliceMap.get(id);

        if (slice != null)
        {
            slice.x = this.x + xLocal;
            slice.y = this.y + yLocal;
            slice.setGraphicSize(Std.int(targetW), Std.int(targetH));
            slice.updateHitbox();
        }
    }

    public function getHoveredElement():IUiEntry
    {
        if (targetAlpha == 0 || !clickable) return null;

        if (FlxG.mouse.overlaps(hitbox)) return this;

        for (item in itemMap)
        {
            if (FlxG.mouse.overlaps(item))
                return this;
        }
        
        return null;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        for (slice in sliceMap)
            slice.alpha = MathUtil.smoothLerpPrecision(slice.alpha, targetAlpha, elapsed, 0.1);
    }
}

class Item extends FlxSpriteGroup
{
    public var clickable:Bool = true;
    public var label:FlxBitmapText;
    public var altLabel:FlxBitmapText;

    private var bgHitbox:FunkinSprite;
    private var callback:() -> Void;
    private var parentMenu:ContextMenu;

    public function new(x:Int, y:Int, width:Float, params:ContextMenuItem, parentMenu:ContextMenu)
    {
        super(x, y);

        this.callback = params.callback;
        this.parentMenu = parentMenu;

        var itemHeight:Int = 30;
        bgHitbox = new FunkinSprite(3, 0).makeGraphic(Std.int(width - 6), itemHeight, FlxColor.WHITE);
        bgHitbox.alpha = 0;
        add(bgHitbox);

        var altWidth:Float = 0;
        if (params.altText != null) 
        {
            altLabel = new FlxBitmapText(0, 0, params.altText, Paths.getAngelFont('jetbrains'));
            altLabel.scale.set(0.28, 0.28);
            altLabel.alpha = parentMenu.targetAlpha / 3;
            altLabel.updateHitbox();
            altLabel.x = bgHitbox.width - altLabel.width - 5;
            altLabel.y = (itemHeight - altLabel.height) / 2;
            altLabel.ID = 2;
            add(altLabel);
            altWidth = altLabel.width + 10;
        }

        var scaleFactor:Float = 0.35;
        label = new FlxBitmapText(0, 0, params.text, Paths.getAngelFont('jetbrains'));
        label.scale.set(scaleFactor, scaleFactor);
        label.ID = 1;
        label.updateHitbox();

        var maxLabelWidth:Float = width - altWidth - 15;

        while (label.width > maxLabelWidth && scaleFactor > 0.1)
        {
            scaleFactor -= 0.02;
            label.scale.set(scaleFactor, scaleFactor);
            label.updateHitbox();
        }

        label.x = 10;
        label.y = (itemHeight - label.height) / 2;
        add(label);

        if (params.separate)
        {
            var separator:Separator = new Separator({position: [12, itemHeight + 1], size: [Std.int(width - 26), 2], alpha: 0.3, color: 0xFFC1CEFF, blending: true});
            separator.ID = 1;
            add(separator);
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        for (txt in this.members)
        {
            if (txt.ID != 1 && txt.ID != 2) continue;

            txt.alpha = MathUtil.smoothLerpPrecision(txt.alpha, txt.ID == 1 ? parentMenu.targetAlpha : parentMenu.targetAlpha / 3, elapsed, 0.1);
        }

        if (!clickable || !UiManager.hasFocus(parentMenu))
        {
            bgHitbox.alpha = MathUtil.smoothLerpPrecision(bgHitbox.alpha, 0, elapsed, 0.1);
            return;
        }

        if (FlxG.mouse.overlaps(bgHitbox))
        {
            bgHitbox.alpha = MathUtil.smoothLerpPrecision(bgHitbox.alpha, parentMenu.targetAlpha / 4, elapsed, 0.1);

            if (FlxG.mouse.justPressed)
            {
                if (callback != null)
                    callback();

                if (parentMenu != null)
                    parentMenu.hide();
            }
        }
        else
        {
            bgHitbox.alpha = MathUtil.smoothLerpPrecision(bgHitbox.alpha, 0.0, elapsed, 0.1);
        }
    }
}