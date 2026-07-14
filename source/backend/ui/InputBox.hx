package backend.ui;

import backend.assets.FunkinSprite;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import openfl.events.KeyboardEvent;

typedef InputBoxParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
    var type:String; // "LETTER", "NUMBER" or "ANY"
    var ?autocompleteList:Array<String>;
    var callback:String->Void;
}

class InputBox extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;

    private function get_priority():Bool
    { 
        return isFocused || _priority;
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
        if (!clickable) 
        {
            isFocused = false;
            showCaret = false;
            updateTextDisplay();
        }
        return value;
    }

    private var params:InputBoxParams;
    var sliceMap:Map<String, FunkinSprite> = [];
    var atlasFrames:FlxAtlasFrames;

    public var value:String = "";

    var hitbox:FunkinSprite;
    var caret:FunkinSprite; 
    var textInput:FlxBitmapText;
    var autocompleteText:FlxBitmapText;
    
    public var isFocused:Bool = false;
    private var showCaret:Bool = false;
    private var caretTimer:Float = 0;

    private var holdTimer:Float = 0;
    private var holdDelay:Float = 0.5;
    private var rapidRate:Float = 0.04;

    private var currentAutocompleteMatch:String = "";

    private var hasScrollbar:Bool = false;
    private var scrollbarBg:FunkinSprite;
    private var scrollbarThumb:FunkinSprite;
    
    private var currentScroll:Float = 0;
    private var targetScroll:Float = 0;
    private var maxScroll:Float = 0;
    
    private var isDraggingScrollbar:Bool = false;
    private var scrollDragOffset:Float = 0;

    private var dummyWidth:Float = -1;
    private var textTrueWidth:Float = 0;

    public function new(params:InputBoxParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);
        this.params = params;

        backend.ui.UiManager.register(this);

        atlasFrames = Paths.getSparrowAtlas("engine/ui/box_field"); 

        var w:Float = (params != null && params.size != null) ? params.size[0] : 150;
        var h:Float = (params != null && params.size != null) ? params.size[1] : 40;

        var cw:Float = Math.min(10.0, w / 2);
        var ch:Float = Math.min(10.0, h / 2);

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

        hitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(w), Std.int(h), FlxColor.TRANSPARENT);
        add(hitbox);

        var textScale:Float = (h / 40.0) * 0.3; 
        
        autocompleteText = new FlxBitmapText(10, 10, "", Paths.getAngelFont('jetbrains/solid'));
        autocompleteText.scale.set(textScale, textScale);
        autocompleteText.autoSize = true; 
        autocompleteText.wordWrap = false;
        autocompleteText.alpha = 0.4;
        autocompleteText.updateHitbox();
        add(autocompleteText);

        textInput = new FlxBitmapText(10, 10, value, Paths.getAngelFont('jetbrains/solid'));
        textInput.scale.set(textScale, textScale);
        textInput.autoSize = true; 
        textInput.wordWrap = false;
        textInput.updateHitbox();
        add(textInput);

        caret = new FunkinSprite(0, 0).makeGraphic(1, Std.int(textInput.height * 0.9), 0xFFFFFFFF);
        caret.visible = false;
        add(caret);

        scrollbarBg = new FunkinSprite(10, h - 4).makeGraphic(Std.int(w - 20), 4, 0x88000000);
        add(scrollbarBg);
        
        scrollbarThumb = new FunkinSprite(10, h - 4).makeGraphic(10, 4, 0xFFBCBCBC);
        add(scrollbarThumb);

        updateTextDisplay();
        checkAutocomplete();

        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    }

    private function createSlice(xPos:Float, yPos:Float, sliceName:String, targetW:Float, targetH:Float):FunkinSprite
    {
        var slice = new FunkinSprite(xPos, yPos);
        slice.frames = atlasFrames;

        slice.animation.addByNames("idle", ["box-" + sliceName], 1, false);
        slice.animation.play("idle");
        
        slice.origin.set(0, 0);
        
        if (targetW <= 0.01)
            targetW = 0.01;

        if (targetH <= 0.01)
            targetH = 0.01;

        slice.setGraphicSize(targetW, targetH);
        slice.updateHitbox();

        add(slice);
        return slice;
    }

    override public function destroy()
    {
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

        super.destroy();
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable)
            return null;

        if (FlxG.mouse.overlaps(hitbox))
            return this;

        if (hasScrollbar && isFocused && (FlxG.mouse.overlaps(scrollbarBg) || FlxG.mouse.overlaps(scrollbarThumb)))
            return this;

        return null;
    }

    private function onKeyDown(e:KeyboardEvent):Void
    {
        if (isFocused && clickable)
        {
            if (e.charCode >= 32 && e.charCode <= 126)
            {
                var char = String.fromCharCode(e.charCode);
                
                if (params != null)
                {
                    if (params.type == "NUMBER" && !~/[0-9\.\-]/.match(char))
                        return;

                    if (params.type == "LETTER" && !~/[a-zA-Z\s]/.match(char))
                        return;
                }
                
                insertText(char);
            }
        }
    }

    private function checkAutocomplete()
    {
        currentAutocompleteMatch = "";
        autocompleteText.text = "";
        
        if (value.length == 0 || params == null || params.autocompleteList == null || params.autocompleteList.length == 0) return;

        var lowerValue = value.toLowerCase();
        
        for (word in params.autocompleteList)
        {
            if (StringTools.startsWith(word.toLowerCase(), lowerValue) && word.length > value.length)
            {
                currentAutocompleteMatch = word;
                autocompleteText.text = value + word.substring(value.length);
                autocompleteText.updateHitbox();

                break;
            }
        }
    }

    private function insertText(t:String)
    {
        value += t;
        showCaret = true; 
        caretTimer = 0;
        updateTextDisplay();
        checkAutocomplete();
        
        targetScroll = maxScroll; 
        if (params != null && params.callback != null) params.callback(value);
    }

    private function backspace()
    {
        if (value.length > 0)
        {
            value = value.substring(0, value.length - 1);
            showCaret = true;
            caretTimer = 0;
            updateTextDisplay();
            checkAutocomplete();

            targetScroll = maxScroll; 

            if (params != null && params.callback != null)
                params.callback(value);
        }
    }

    private function updateTextDisplay()
    {
        if (dummyWidth == -1)
        {
            textInput.text = "_";
            textInput.updateHitbox();
            dummyWidth = textInput.width;
        }

        textInput.text = value + "_";
        textInput.updateHitbox();
        textTrueWidth = textInput.width - dummyWidth;

        if (value.length == 0) textTrueWidth = 0;

        textInput.text = value;
        textInput.updateHitbox();

        var maxVisibleWidth = hitbox.width - 15; 
        var totalWidthWithCaret = textTrueWidth + 5; 

        if (totalWidthWithCaret > maxVisibleWidth)
        {
            hasScrollbar = true;
            maxScroll = totalWidthWithCaret - maxVisibleWidth;
        }
        else
        {
            hasScrollbar = false;
            maxScroll = 0;
            targetScroll = 0;
            currentScroll = 0; 
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (!clickable) return;

        if (FlxG.mouse.justPressed)
        {
            if (backend.ui.UiManager.hasFocus(this)) 
            {
                isFocused = true;
                showCaret = true;
                caretTimer = 0;
            }
            else
            {
                isFocused = false;
                showCaret = false;
            }
        }

        if (isFocused)
        {
            caretTimer += elapsed;

            if (caretTimer >= 0.5)
            {
                showCaret = !showCaret;
                caretTimer = 0;
            }

            if (FlxG.keys.justPressed.TAB && currentAutocompleteMatch != "")
            {
                value = currentAutocompleteMatch;
                showCaret = true;
                caretTimer = 0;
                
                updateTextDisplay();
                checkAutocomplete();
                
                targetScroll = maxScroll; 

                if (params != null && params.callback != null)
                    params.callback(value);
            }

            if (FlxG.keys.justPressed.BACKSPACE)
            {
                backspace();
                holdTimer = 0;
            }
            else if (FlxG.keys.pressed.BACKSPACE)
            {
                holdTimer += elapsed;
                if (holdTimer >= holdDelay)
                {
                    holdTimer -= rapidRate;
                    backspace();
                }
            }
        }

        if (hasScrollbar && isFocused)
        {
            var isMouseInBox = FlxG.mouse.overlaps(hitbox);

            if (FlxG.mouse.wheel != 0 && isMouseInBox)
            {
                targetScroll -= FlxG.mouse.wheel * 20; 
                if (targetScroll < 0) targetScroll = 0;
                if (targetScroll > maxScroll) targetScroll = maxScroll;
            }

            if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollbarThumb))
            {
                isDraggingScrollbar = true;
                scrollDragOffset = FlxG.mouse.x - scrollbarThumb.x;
            }

            if (FlxG.mouse.pressed && isDraggingScrollbar)
            {
                var trackLeft = this.x + 10;
                var trackWidth = hitbox.width - 20;
                var newThumbX = FlxG.mouse.x - scrollDragOffset;
                
                var scrollRatio = (newThumbX - trackLeft) / (trackWidth - scrollbarThumb.width);
                if (scrollRatio < 0) scrollRatio = 0;
                if (scrollRatio > 1) scrollRatio = 1;
                
                targetScroll = scrollRatio * maxScroll;
            }

            if (FlxG.mouse.justReleased)
            {
                isDraggingScrollbar = false;
            }
        }

        currentScroll += (targetScroll - currentScroll) * Math.min(1, elapsed * 15);
        
        if (hasScrollbar && maxScroll > 0)
        {
            var trackLeft = this.x + 10;
            var trackWidth = hitbox.width - 20;
            scrollbarThumb.x = trackLeft + (currentScroll / maxScroll) * (trackWidth - scrollbarThumb.width);
        }

        updateClip();
    }

    private function updateClip()
    {
        textInput.x = this.x + 10 - currentScroll;
        textInput.y = this.y + 1 + (hitbox.height - textInput.height) / 2;

        autocompleteText.x = textInput.x;
        autocompleteText.y = textInput.y;

        caret.x = textInput.x + textTrueWidth + 4;
        caret.y = textInput.y - 1 + (textInput.height - caret.height) / 2;

        var viewLeft = this.x + 10;
        var viewRight = this.x + hitbox.width - 5; 
        
        if (isFocused && showCaret)
        {
            if (caret.x < viewLeft || caret.x > viewRight)
                caret.visible = false;
            else
                caret.visible = true;
        }
        else
        {
            caret.visible = false;
        }

        var txtLeft = textInput.x;
        var txtRight = textInput.x + textTrueWidth + 5;

        if (txtRight <= viewLeft || txtLeft >= viewRight) 
        {
            textInput.visible = false;
        } 
        else 
        {
            textInput.visible = true;
            var cX = Math.max(0, viewLeft - txtLeft);
            var cW = (textTrueWidth + 5) - cX - Math.max(0, txtRight - viewRight);
            
            if (cW <= 0)
                textInput.visible = false;
            else if (cX == 0 && cW >= textInput.width)
                textInput.clipRect = null;
            else
                textInput.clipRect = new FlxRect(cX / textInput.scale.x, 0, cW / textInput.scale.x, 1000); 
        }

        var autoLeft = autocompleteText.x;
        var autoRight = autocompleteText.x + autocompleteText.width + 5;

        if (autoRight <= viewLeft || autoLeft >= viewRight || !isFocused || currentAutocompleteMatch == "") 
            autocompleteText.visible = false;
        else 
        {
            autocompleteText.visible = true;
            var cX = Math.max(0, viewLeft - autoLeft);
            var cW = (autocompleteText.width + 5) - cX - Math.max(0, autoRight - viewRight);
            
            if (cW <= 0)
                autocompleteText.visible = false;
            else if (cX == 0 && cW >= autocompleteText.width)
                autocompleteText.clipRect = null;
            else
                autocompleteText.clipRect = new FlxRect(cX / autocompleteText.scale.x, 0, cW / autocompleteText.scale.x, 1000); 
        }

        if (hasScrollbar && isFocused)
        {
            scrollbarBg.visible = true;
            scrollbarThumb.visible = true;
            
            var trackWidth = hitbox.width - 20;
            var thumbWidth = Math.max(10, ((hitbox.width - 15) / (textTrueWidth + 5)) * trackWidth);
            scrollbarThumb.setGraphicSize(Std.int(thumbWidth), 4);
            scrollbarThumb.updateHitbox();
        }
        else
        {
            scrollbarBg.visible = false;
            scrollbarThumb.visible = false;
        }
    }
}