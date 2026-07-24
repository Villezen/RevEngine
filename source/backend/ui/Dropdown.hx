package backend.ui;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import backend.utils.MathUtil;

typedef DropdownParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var items:Array<DropdownItem>;
    var callback:String->Void;
}

typedef DropdownItem =
{
    var name:String;
    var callback:String->Void;
}

class Dropdown extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;

    private function get_priority():Bool
    { 
        return isDropped || _priority;
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
        for (item in itemMap) item.clickable = value;
        return value;
    }

    public var params:DropdownParams;

    var baseSliceMap:Map<String, FunkinSprite> = [];
    var listSliceMap:Map<String, FunkinSprite> = [];
    var itemMap:Array<DropdownListItem> = [];

    var baseAtlasFrames:FlxAtlasFrames;
    var listAtlasFrames:FlxAtlasFrames;

    var baseHitbox:FunkinSprite;
    var arrowHitbox:FunkinSprite;
    var listHitbox:FunkinSprite;
    var baseLabel:FlxBitmapText;
    var arrow:FunkinSprite;

    public var isDropped:Bool = false;
    public var selectedItem:String = "";

    public var listY:Float = 0;
    public var itemHeight:Float = 20;
    public var visibleItemsCount:Int = 0;

    public var targetListH:Float = 0;
    public var animListH:Float = 0;

    private var hasScrollbar:Bool = false;
    private var scrollbarBg:FunkinSprite;
    private var scrollbarThumb:FunkinSprite;
    
    private var currentScroll:Float = 0;
    private var targetScroll:Float = 0;
    private var maxScroll:Float = 0;
    
    private var isDraggingScrollbar:Bool = false;
    private var scrollDragOffset:Float = 0;

    public function new(params:DropdownParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        backend.ui.UiManager.register(this);

        baseAtlasFrames = Paths.getSparrowAtlas("engine/ui/box_dropdown"); 
        listAtlasFrames = Paths.getSparrowAtlas("engine/ui/box_dropdown_list");

        var w:Float = (params != null && params.size != null) ? params.size[0] : 100;
        var h:Float = (params != null && params.size != null) ? params.size[1] : 20;

        var cw:Float = Math.min(10.0, w / 2);
        var ch:Float = Math.min(10.0, h / 2);
        var midW:Float = w - (cw * 2);
        var midH:Float = h - (ch * 2);

        baseSliceMap.set("tl", createSlice(0, 0, "topleft", cw, ch, baseAtlasFrames));
        baseSliceMap.set("t",  createSlice(cw, 0, "top", midW, ch, baseAtlasFrames));
        baseSliceMap.set("tr", createSlice(w - cw, 0, "topright", cw, ch, baseAtlasFrames));

        baseSliceMap.set("ml", createSlice(0, ch, "middleleft", cw, midH, baseAtlasFrames));
        baseSliceMap.set("m",  createSlice(cw, ch, "middle", midW, midH, baseAtlasFrames));
        baseSliceMap.set("mr", createSlice(w - cw, ch, "middleright", cw, midH, baseAtlasFrames));

        baseSliceMap.set("bl", createSlice(0, h - ch, "bottomleft", cw, ch, baseAtlasFrames));
        baseSliceMap.set("b",  createSlice(cw, h - ch, "bottom", midW, ch, baseAtlasFrames));
        baseSliceMap.set("br", createSlice(w - cw, h - ch, "bottomright", cw, ch, baseAtlasFrames));

        baseHitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(w), Std.int(h), FlxColor.TRANSPARENT);
        add(baseHitbox);

        arrowHitbox = new FunkinSprite(w - h, 0).makeGraphic(Std.int(h), Std.int(h), FlxColor.TRANSPARENT);
        add(arrowHitbox);

        arrow = new FunkinSprite().loadGraphic(Paths.image("engine/ui/dropdownArrow"));
        arrow.setGraphicSize(h, h);
        arrow.updateHitbox();

        var localX:Float = (w - h) + ((h - arrow.width) / 2);
        var localY:Float = 0 + ((h - arrow.height) / 2);
        arrow.setPosition(localX, localY);

        arrow.antialiasing = true;
        add(arrow);

        baseLabel = new FlxBitmapText(10, 0, "", Paths.getAngelFont('jetbrains'));
        baseLabel.scale.set(0.3, 0.3);
        baseLabel.updateHitbox();
        add(baseLabel);

        itemHeight = 20; 
        listY = h;       
        visibleItemsCount = (params != null && params.items != null) ? Std.int(Math.min(params.items.length, 5)) : 0;
        
        targetListH = (visibleItemsCount * itemHeight) + 10;
        animListH = 0.0;

        var listCh:Float = Math.min(10.0, targetListH / 2);
        var listMidH:Float = targetListH - (listCh * 2);

        listSliceMap.set("tl", createSlice(0, listY, "topleft", cw, listCh, listAtlasFrames));
        listSliceMap.set("t",  createSlice(cw, listY, "top", midW, listCh, listAtlasFrames));
        listSliceMap.set("tr", createSlice(w - cw, listY, "topright", cw, listCh, listAtlasFrames));

        listSliceMap.set("ml", createSlice(0, listY + listCh, "middleleft", cw, listMidH, listAtlasFrames));
        listSliceMap.set("m",  createSlice(cw, listY + listCh, "middle", midW, listMidH, listAtlasFrames));
        listSliceMap.set("mr", createSlice(w - cw, listY + listCh, "middleright", cw, listMidH, listAtlasFrames));

        listSliceMap.set("bl", createSlice(0, listY + targetListH - listCh, "bottomleft", cw, listCh, listAtlasFrames));
        listSliceMap.set("b",  createSlice(cw, listY + targetListH - listCh, "bottom", midW, listCh, listAtlasFrames));
        listSliceMap.set("br", createSlice(w - cw, listY + targetListH - listCh, "bottomright", cw, listCh, listAtlasFrames));

        for (slice in listSliceMap)
            slice.origin.set(0, 0);

        listHitbox = new FunkinSprite(0, listY).makeGraphic(Std.int(w), Std.int(targetListH), FlxColor.TRANSPARENT);
        listHitbox.origin.set(0, 0);
        add(listHitbox);

        var currentY:Float = listY + 5; 
        var itemWidth = hasScrollbar ? (w - 10) : w;

        if (params != null && params.items != null)
        {
            for (i in 0...params.items.length)
            {
                var itm = params.items[i];
                var listItem = new DropdownListItem(0, currentY, itemWidth, itemHeight, itm, this);
                add(listItem);
                itemMap.push(listItem);
                currentY += itemHeight;
            }
        }

        if (params != null && params.items != null && params.items.length > 5)
        {
            hasScrollbar = true;
            maxScroll = (params.items.length - 5) * itemHeight;
            
            var scrollbarWidth:Float = 6;
            
            scrollbarBg = new FunkinSprite(w - scrollbarWidth - 3, listY + 5).makeGraphic(Std.int(scrollbarWidth), 1, 0x88000000);
            scrollbarBg.origin.set(0, 0);
            add(scrollbarBg);
            
            scrollbarThumb = new FunkinSprite(w - scrollbarWidth - 2, listY + 5).makeGraphic(Std.int(scrollbarWidth), 1, 0xFFBCBCBC);
            scrollbarThumb.origin.set(0, 0);
            add(scrollbarThumb);
        }

        if (params != null && params.items != null && params.items.length > 0)
            selectItem(params.items[0].name); 
        else
            hideList();
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float, frames:FlxAtlasFrames):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = frames;

        slice.animation.addByNames("idle", ["box-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        
        if (targetW <= 0.01) targetW = 0.01;
        if (targetH <= 0.01) targetH = 0.01;

        slice.setGraphicSize(targetW, targetH);
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    public function showList()
    {
        isDropped = true;
    }

    public function hideList()
    {
        isDropped = false;
        isDraggingScrollbar = false;
    }

    public function selectItem(name:String)
    {
        selectedItem = name;
        baseLabel.text = name;
        
        var scaleFactor:Float = 0.3;
        baseLabel.scale.set(scaleFactor, scaleFactor);
        baseLabel.updateHitbox();

        var maxLabelWidth:Float = baseHitbox.width - arrowHitbox.width - 15;

        while (baseLabel.width > maxLabelWidth && scaleFactor > 0.05)
        {
            scaleFactor -= 0.02; 
            baseLabel.scale.set(scaleFactor, scaleFactor);
            baseLabel.updateHitbox();
        }

        baseLabel.y = baseHitbox.y + (baseHitbox.height - baseLabel.height) / 2;
        hideList();
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable) return null;
        
        if (FlxG.mouse.overlaps(baseHitbox)) return this;
        
        if (isDropped)
        {
            if (FlxG.mouse.overlaps(listHitbox)) return this;
            
            if (isDraggingScrollbar) return this;
            
            if (hasScrollbar && (FlxG.mouse.overlaps(scrollbarBg) || FlxG.mouse.overlaps(scrollbarThumb))) return this;
            
            for (item in itemMap)
            {
                if (FlxG.mouse.overlaps(item.bgHitbox)) return this;
            }
        }
        return null;
    }

    private function updateListBounds(currentH:Float)
    {
        var w:Float = baseHitbox.width;
        var cw:Float = Math.min(10.0, w / 2);
        var ch:Float = Math.min(10.0, currentH / 2);
        
        var midW:Float = Math.max(0.01, w - (cw * 2));
        var midH:Float = Math.max(0.01, currentH - (ch * 2));
        
        if (cw <= 0.01) cw = 0.01;
        if (ch <= 0.01) ch = 0.01;

        listSliceMap.get("tl").setGraphicSize(cw, ch);
        listSliceMap.get("tl").setPosition(this.x, this.y + listY);

        listSliceMap.get("t").setGraphicSize(midW, ch);
        listSliceMap.get("t").setPosition(this.x + cw, this.y + listY);

        listSliceMap.get("tr").setGraphicSize(cw, ch);
        listSliceMap.get("tr").setPosition(this.x + w - cw, this.y + listY);

        listSliceMap.get("ml").setGraphicSize(cw, midH);
        listSliceMap.get("ml").setPosition(this.x, this.y + listY + ch);

        listSliceMap.get("m").setGraphicSize(midW, midH);
        listSliceMap.get("m").setPosition(this.x + cw, this.y + listY + ch);

        listSliceMap.get("mr").setGraphicSize(cw, midH);
        listSliceMap.get("mr").setPosition(this.x + w - cw, this.y + listY + ch);

        listSliceMap.get("bl").setGraphicSize(cw, ch);
        listSliceMap.get("bl").setPosition(this.x, this.y + listY + currentH - ch);

        listSliceMap.get("b").setGraphicSize(midW, ch);
        listSliceMap.get("b").setPosition(this.x + cw, this.y + listY + currentH - ch);

        listSliceMap.get("br").setGraphicSize(cw, ch);
        listSliceMap.get("br").setPosition(this.x + w - cw, this.y + listY + currentH - ch);

        for (slice in listSliceMap) slice.updateHitbox();

        listHitbox.setGraphicSize(Std.int(w), Std.int(currentH));
        listHitbox.updateHitbox();
        listHitbox.setPosition(this.x, this.y + listY);
    }

    public function updateScrollAndItems(elapsed:Float, currentH:Float)
    {
        if (hasScrollbar)
        {
            currentScroll += (targetScroll - currentScroll) * Math.min(1, elapsed * 15);
            
            var trackTop = this.y + listY + 5;
            var trackHeight = Math.max(0.1, currentH - 10);
            
            scrollbarBg.setGraphicSize(6, trackHeight);
            scrollbarBg.updateHitbox();
            scrollbarBg.setPosition(this.x + baseHitbox.width - 9, trackTop);

            if (trackHeight <= 2)
                scrollbarThumb.visible = false;
            else
            {
                scrollbarThumb.visible = true;
                var thumbHeight = Math.max(10, (5.0 / params.items.length) * trackHeight);
                scrollbarThumb.setGraphicSize(6, thumbHeight);
                scrollbarThumb.updateHitbox();
                scrollbarThumb.x = this.x + baseHitbox.width - 9;
                
                var maxThumbY = trackTop + trackHeight - thumbHeight;
                if (maxThumbY < trackTop) maxThumbY = trackTop;

                var scrollRatio = maxScroll > 0 ? (currentScroll / maxScroll) : 0;
                scrollbarThumb.y = trackTop + (scrollRatio * (maxThumbY - trackTop));
            }
        }

        var viewTop = this.y + listY + 5;
        var viewBottom = this.y + listY + currentH - 5;
        
        for (i in 0...itemMap.length)
        {
            var item = itemMap[i];
            var baseItemY = listY + 5 + (i * itemHeight);
            
            item.y = this.y + baseItemY - currentScroll;
            item.updateClip(viewTop, viewBottom);
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!clickable)
        {
            if (isDropped)
                hideList();
            
            return;
        }

        var targetH = isDropped ? targetListH : 0.0;
        animListH = MathUtil.smoothLerpPrecision(animListH, targetH, elapsed, 0.15);
        
        var isVisible = animListH > 0.5;

        for (slice in listSliceMap) slice.visible = isVisible;
        listHitbox.visible = isVisible;
        if (hasScrollbar) {
            scrollbarBg.visible = isVisible;
            scrollbarThumb.visible = isVisible;
        }
        for (item in itemMap) item.visible = isVisible;

        if (isVisible)
        {
            updateListBounds(animListH);
            updateScrollAndItems(elapsed, animListH);
        } 
        else if (!isDropped)
        {
            currentScroll = 0;
            targetScroll = 0;
        }

        var boxHovered = FlxG.mouse.overlaps(baseHitbox);
        
        arrow.color = boxHovered ? 0xFFCCCCCC : 0xFFFFFFFF;
        arrow.flipY = isDropped ? true : false;

        if (FlxG.mouse.justPressed)
        {
            if (backend.ui.UiManager.hasFocus(this))
            {
                if (boxHovered)
                {
                    if (isDropped) hideList();
                    else showList();
                }
                else if (isDropped && !FlxG.mouse.overlaps(listHitbox))
                {
                    hideList();
                }
            }
            else
            {
                if (isDropped) hideList();
            }
        }

        if (isDropped && hasScrollbar)
        {
            var isMouseInList = FlxG.mouse.overlaps(listHitbox);

            if (FlxG.mouse.wheel != 0 && isMouseInList)
            {
                targetScroll -= FlxG.mouse.wheel * itemHeight;
                if (targetScroll < 0) targetScroll = 0;
                if (targetScroll > maxScroll) targetScroll = maxScroll;
            }

            if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollbarThumb))
            {
                isDraggingScrollbar = true;
                scrollDragOffset = FlxG.mouse.y - scrollbarThumb.y;
            }

            if (FlxG.mouse.pressed && isDraggingScrollbar)
            {
                var trackTop = this.y + listY + 5;
                var trackHeight = visibleItemsCount * itemHeight;
                var newThumbY = FlxG.mouse.y - scrollDragOffset;
                
                var scrollRatio = (newThumbY - trackTop) / (trackHeight - scrollbarThumb.height);
                if (scrollRatio < 0) scrollRatio = 0;
                if (scrollRatio > 1) scrollRatio = 1;
                
                targetScroll = scrollRatio * maxScroll;
            }

            if (FlxG.mouse.justReleased)
            {
                isDraggingScrollbar = false;
            }
        }
    }
}

class DropdownListItem extends FlxSpriteGroup
{
    public var clickable:Bool = true;
    public var label:FlxBitmapText;
    public var bgHitbox:FunkinSprite;
    
    private var itemData:DropdownItem;
    private var parentDropdown:Dropdown;

    public function new(x:Float, y:Float, width:Float, height:Float, data:DropdownItem, parent:Dropdown)
    {
        super(x, y);
        this.itemData = data;
        this.parentDropdown = parent;

        bgHitbox = new FunkinSprite(4, 0).loadGraphic(Paths.image("engine/ui/dropdownSelection"));
        bgHitbox.setGraphicSize(Std.int(parentDropdown.params.size[0]) - 20, Std.int(height));
        bgHitbox.updateHitbox();
        bgHitbox.alpha = 0.0;
        add(bgHitbox);

        var scaleFactor:Float = 0.28;
        label = new FlxBitmapText(10, 0, data.name, Paths.getAngelFont('jetbrains/solid'));
        label.scale.set(scaleFactor, scaleFactor); 
        label.updateHitbox();

        var maxLabelWidth:Float = width - 15; 
        
        while (label.width > maxLabelWidth && scaleFactor > 0.05)
        {
            scaleFactor -= 0.02; 
            label.scale.set(scaleFactor, scaleFactor);
            label.updateHitbox();
        }

        add(label);
        label.y = bgHitbox.y + (bgHitbox.height - label.height) / 2;
    }

    public function updateClip(viewTop:Float, viewBottom:Float)
    {
        var bgTop = bgHitbox.y;
        var bgBottom = bgHitbox.y + bgHitbox.height;
        
        if (bgBottom <= viewTop || bgTop >= viewBottom) 
        {
            bgHitbox.visible = false;
        } 
        else 
        {
            bgHitbox.visible = true;
            var cY = Math.max(0, viewTop - bgTop);
            var cH = bgHitbox.height - cY - Math.max(0, bgBottom - viewBottom);
            
            if (cH <= 0) {
                bgHitbox.visible = false;
            } else if (cY == 0 && cH >= bgHitbox.height) {
                bgHitbox.clipRect = null; 
            } else {
                bgHitbox.clipRect = new flixel.math.FlxRect(0, cY, 1000, cH); 
            }
        }

        var lblTop = label.y;
        var lblBottom = label.y + label.height;
        
        if (lblBottom <= viewTop || lblTop >= viewBottom) 
        {
            label.visible = false;
        } 
        else 
        {
            label.visible = true;
            var cY = Math.max(0, viewTop - lblTop);
            var cH = label.height - cY - Math.max(0, lblBottom - viewBottom);
            
            if (cH <= 0) {
                label.visible = false;
            } else if (cY == 0 && cH >= label.height) {
                label.clipRect = null;
            } else {
                label.clipRect = new flixel.math.FlxRect(0, cY / label.scale.y, 1000, cH / label.scale.y); 
            }
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!visible || !clickable || !backend.ui.UiManager.hasFocus(parentDropdown))
        {
            bgHitbox.alpha = 0.0;
            return;
        }

        var viewTop = parentDropdown.y + parentDropdown.listY + 5;
        var viewBottom = viewTop + (parentDropdown.visibleItemsCount * parentDropdown.itemHeight);
        
        var isMouseInView = FlxG.mouse.y >= viewTop && FlxG.mouse.y <= viewBottom;

        if (isMouseInView && FlxG.mouse.overlaps(bgHitbox))
        {
            bgHitbox.alpha = 0.3;
            
            if (FlxG.mouse.justPressed)
            {
                parentDropdown.selectItem(itemData.name);

                if(parentDropdown.params.callback != null)
                    parentDropdown.params.callback(itemData.name);
                
                if (itemData.callback != null)
                    itemData.callback(itemData.name);
            }
        }
        else
        {
            bgHitbox.alpha = 0.0;
        }
    }
}