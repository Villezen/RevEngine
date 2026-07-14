package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import backend.ui.ContextMenu;

typedef BarParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var items:Array<BarItem>;
}

typedef BarItem =
{
    var name:String;
    var items:Array<ContextMenuItem>;
}

class Bar extends FlxSpriteGroup implements IUiEntry
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
        for(ui in itemUIs) ui.clickable = value;
        return value;
    }

    private var params:BarParams;

    var sliceMap:Map<String, FunkinSprite> = [];
    var atlasFrames:FlxAtlasFrames;

    var baseHitbox:FunkinSprite;
    var itemUIs:Array<BarItemUI> = [];
    
    public var contextMenu:ContextMenu;
    public var activeMenuIndex:Int = -1;

    public function new(params:BarParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;

        super(startX, startY);
        this.params = params;

        UiManager.register(this);

        var w:Float = (params.size != null) ? params.size[0] : 100;
        var h:Float = (params.size != null) ? params.size[1] : 20;

        var cw:Float = Math.min(8.0, w / 2);
        var ch:Float = Math.min(8.0, h / 2);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/bar");

        sliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch));
        sliceMap.set("t",  createSlice(cw, 0, "top", w - (cw * 2), ch));
        sliceMap.set("tr", createSlice(w - cw, 0, "topright", cw, ch));

        sliceMap.set("ml", createSlice(0, ch, "middleleft", cw, h - (ch * 2)));
        sliceMap.set("m",  createSlice(cw, ch, "middle", w - (cw * 2), h - (ch * 2)));
        sliceMap.set("mr", createSlice(w - cw, ch, "middleright", cw, h - (ch * 2)));

        sliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch));
        sliceMap.set("b",  createSlice(cw, h - ch, "bottom", w - (cw * 2), ch));
        sliceMap.set("br", createSlice(w - cw, h - ch, "bottomright", cw, ch));

        baseHitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(w), Std.int(h), FlxColor.TRANSPARENT);
        add(baseHitbox);

        var currentX:Float = 5;
        if (params.items != null)
        {
            for (i in 0...params.items.length)
            {
                var item = params.items[i];
                var itemUI = new BarItemUI(currentX, 0, h, item, this, i);
                add(itemUI);
                itemUIs.push(itemUI);
                
                currentX += itemUI.bgHitbox.width + 5;
            }
        }

        contextMenu = new ContextMenu({position: [0, 0], width: 450, items: []});
        contextMenu.hide();
        add(contextMenu);
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

        add(slice);
        return slice;
    }

    public function showMenu(index:Int)
    {
        var itemData = params.items[index];
        var itemUI = itemUIs[index];

        if (itemData.items != null && itemData.items.length > 0)
        {
            contextMenu.reload(itemData.items);
            
            contextMenu.x = itemUI.x;
            contextMenu.y = this.y + params.size[1];
            contextMenu.show();
            
            activeMenuIndex = index;
        }
    }

    public function hideMenu()
    {
        contextMenu.hide();
        activeMenuIndex = -1;
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable) return null;

        if (contextMenu != null)
            if (contextMenu.visible && contextMenu.getHoveredElement() != null) return this;

        for (ui in itemUIs)
        {
            if (FlxG.mouse.overlaps(ui.bgHitbox))
                return this;
        }

        return null;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (activeMenuIndex != -1 && !contextMenu.visible)
        {
            activeMenuIndex = -1;
        }

        if (!clickable)
        {
            if (activeMenuIndex != -1) hideMenu();
            return;
        }

        var hasFocus = UiManager.hasFocus(this);

        if (activeMenuIndex != -1 && hasFocus)
        {
            for (i in 0...itemUIs.length)
            {
                if (FlxG.mouse.overlaps(itemUIs[i].bgHitbox) && activeMenuIndex != i)
                {
                    showMenu(i);
                    break;
                }
            }
        }

        if (FlxG.mouse.justPressed)
        {
            if (hasFocus)
            {
                var clickedItem = false;
                for (i in 0...itemUIs.length)
                {
                    if (FlxG.mouse.overlaps(itemUIs[i].bgHitbox))
                    {
                        clickedItem = true;
                        if (activeMenuIndex == i)
                        {
                            hideMenu(); 
                        }
                        else
                        {
                            showMenu(i);
                        }
                        break;
                    }
                }

                if (!clickedItem)
                {
                    if (contextMenu.visible && contextMenu.getHoveredElement() == null && !FlxG.mouse.overlaps(baseHitbox))
                    {
                        hideMenu();
                    }
                }
            }
            else
            {
                if (activeMenuIndex != -1 && !UiManager.hasFocus(contextMenu))
                {
                    hideMenu();
                }
            }
        }
    }
}

class BarItemUI extends FlxSpriteGroup
{
    public var clickable:Bool = true;
    public var label:FlxBitmapText;
    public var bgHitbox:FunkinSprite;
    
    private var itemData:BarItem;
    private var parentBar:Bar;
    public var index:Int;

    public function new(x:Float, y:Float, height:Float, data:BarItem, parent:Bar, index:Int)
    {
        super(x, y);
        this.itemData = data;
        this.parentBar = parent;
        this.index = index;

        label = new FlxBitmapText(0, 0, data.name, Paths.getAngelFont('jetbrains'));
        label.scale.set(0.3, 0.3);
        label.updateHitbox();

        var itemWidth = label.width + 12; 
        
        bgHitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(itemWidth), Std.int(height), FlxColor.WHITE);
        bgHitbox.alpha = 0.0;
        add(bgHitbox);

        add(label);

        label.x = bgHitbox.x + (bgHitbox.width - label.width) / 2;
        label.y = bgHitbox.y + (bgHitbox.height - label.height) / 2;
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!visible || !clickable || !UiManager.hasFocus(parentBar))
        {
            bgHitbox.alpha = 0.0;
            return;
        }

        if (FlxG.mouse.overlaps(bgHitbox))
        {
            bgHitbox.alpha = 0.3;
        }
        else
        {
            if (parentBar.activeMenuIndex == index)
                bgHitbox.alpha = 0.3;
            else
                bgHitbox.alpha = 0.0;
        }
    }
}