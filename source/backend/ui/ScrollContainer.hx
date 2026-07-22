package backend.ui;

import backend.assets.FunkinSprite;
import backend.utils.MathUtil;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

typedef ScrollContainerParams =
{
    var position:Array<Int>;
    var size:Array<Int>;
}

class ScrollContainer extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;

    private function get_priority():Bool
    {
        for (item in _content)
        {
            if (Std.isOfType(item, IUiEntry) && (cast item:IUiEntry).priority)
                return true;
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

    var _params:ScrollContainerParams;

    var _viewportW:Float;
    var _viewportH:Float;

    var _background:FunkinSprite;
    var _hitbox:FunkinSprite;

    var _scrollbarBg:FunkinSprite;
    var _scrollbarThumb:FunkinSprite;

    var _content:Array<FlxSprite> = [];
    var _contentX:Array<Float> = [];
    var _contentY:Array<Float> = [];
    var _contentH:Array<Float> = [];

    var _contentHeight:Float = 0;
    var _maxScroll:Float = 0;

    var _currentScroll:Float = 0;
    var _targetScroll:Float = 0;

    var _isDraggingScrollbar:Bool = false;
    var _scrollDragOffset:Float = 0;

    static inline final SCROLLBAR_WIDTH:Float = 6;

    public function new(params:ScrollContainerParams)
    {
        var startX:Int = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Int = (params != null && params.position != null) ? params.position[1] : 0;

        super(startX, startY);
        this._params = params;

        UiManager.register(this);

        _viewportW = (params != null && params.size != null) ? params.size[0] : 100;
        _viewportH = (params != null && params.size != null) ? params.size[1] : 100;

        _background = new FunkinSprite(0, 0).makeGraphic(Std.int(_viewportW), Std.int(_viewportH), 0x22000000);
        _background.origin.set(0, 0);
        add(_background);

        _hitbox = new FunkinSprite(0, 0).makeGraphic(Std.int(_viewportW), Std.int(_viewportH), FlxColor.TRANSPARENT);
        _hitbox.origin.set(0, 0);
        add(_hitbox);

        _scrollbarBg = new FunkinSprite(0, 0).makeGraphic(Std.int(SCROLLBAR_WIDTH), Std.int(_viewportH), 0x88000000);
        _scrollbarBg.origin.set(0, 0);
        add(_scrollbarBg);

        _scrollbarThumb = new FunkinSprite(0, 0).makeGraphic(Std.int(SCROLLBAR_WIDTH), 1, 0xFFBCBCBC);
        _scrollbarThumb.origin.set(0, 0);
        add(_scrollbarThumb);
    }

    public function clearContent():Void
    {
        for (item in _content)
        {
            if (Std.isOfType(item, IUiEntry))
                UiManager.unregister(cast item);

            remove(item);
            item.destroy();
        }

        _content = [];
        _contentX = [];
        _contentY = [];
        _contentH = [];

        _contentHeight = 0;
        _maxScroll = 0;

        _currentScroll = 0;
        _targetScroll = 0;
    }

    public function addContent(item:FlxSprite, localX:Float, localY:Float, rowHeight:Float):Void
    {
        if (Std.isOfType(item, IUiEntry))
            UiManager.unregister(cast item);

        add(item);

        _content.push(item);
        _contentX.push(localX);
        _contentY.push(localY);
        _contentH.push(rowHeight);

        var bottom:Float = localY + rowHeight;
        if (bottom > _contentHeight) _contentHeight = bottom;

        _maxScroll = Math.max(0, _contentHeight - _viewportH);

        reposition();
    }

    public function getHoveredElement():IUiEntry
    {
        if (!visible || !clickable) return null;

        if (_maxScroll > 0 && (FlxG.mouse.overlaps(_scrollbarThumb) || FlxG.mouse.overlaps(_scrollbarBg)))
            return this;

        if (_isDraggingScrollbar) return this;

        if (!FlxG.mouse.overlaps(_hitbox)) return null;

        var i:Int = _content.length - 1;
        while (i >= 0)
        {
            var item = _content[i];

            if (item.visible && Std.isOfType(item, IUiEntry))
            {
                var hovered = (cast item:IUiEntry).getHoveredElement();
                if (hovered != null) return hovered;
            }

            i--;
        }

        return this;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (clickable && _maxScroll > 0)
        {
            if (FlxG.mouse.wheel != 0 && FlxG.mouse.overlaps(_hitbox))
                setTargetScroll(_targetScroll - FlxG.mouse.wheel * 24);

            if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(_scrollbarThumb))
            {
                _isDraggingScrollbar = true;
                _scrollDragOffset = FlxG.mouse.y - _scrollbarThumb.y;
            }

            if (FlxG.mouse.pressed && _isDraggingScrollbar)
            {
                var trackTop:Float = this.y;
                var trackHeight:Float = Math.max(1, _viewportH - _scrollbarThumb.height);

                var ratio:Float = (FlxG.mouse.y - _scrollDragOffset - trackTop) / trackHeight;
                setTargetScroll(ratio * _maxScroll);
            }

            if (FlxG.mouse.justReleased)
                _isDraggingScrollbar = false;
        }
        else
        {
            _targetScroll = 0;
            _isDraggingScrollbar = false;
        }

        _currentScroll = MathUtil.smoothLerpPrecision(_currentScroll, _targetScroll, elapsed, 0.05);
        if (Math.abs(_currentScroll - _targetScroll) < 0.1) _currentScroll = _targetScroll;

        reposition();
    }

    inline function setTargetScroll(value:Float):Void
    {
        _targetScroll = value;
        if (_targetScroll < 0) _targetScroll = 0;
        if (_targetScroll > _maxScroll) _targetScroll = _maxScroll;
    }

    function reposition():Void
    {
        _background.setPosition(this.x, this.y);
        _hitbox.setPosition(this.x, this.y);

        var viewTop:Float = this.y;
        var viewBottom:Float = this.y + _viewportH;

        for (i in 0..._content.length)
        {
            var item = _content[i];

            var top:Float = this.y + _contentY[i] - _currentScroll;

            item.x = this.x + _contentX[i];
            item.y = top;

            var inView:Bool = (top >= viewTop - 0.5) && (top + _contentH[i] <= viewBottom + 0.5);

            item.visible = inView;

            if (Std.isOfType(item, IUiEntry))
                (cast item:IUiEntry).clickable = inView && clickable;
        }

        var showBar:Bool = _maxScroll > 0;

        _scrollbarBg.visible = showBar;
        _scrollbarThumb.visible = showBar;

        if (showBar)
        {
            var barX:Float = this.x + _viewportW - SCROLLBAR_WIDTH;

            _scrollbarBg.setGraphicSize(SCROLLBAR_WIDTH, _viewportH);
            _scrollbarBg.updateHitbox();
            _scrollbarBg.setPosition(barX, this.y);

            var thumbHeight:Float = Math.max(16, (_viewportH / _contentHeight) * _viewportH);
            _scrollbarThumb.setGraphicSize(SCROLLBAR_WIDTH, thumbHeight);
            _scrollbarThumb.updateHitbox();

            var ratio:Float = (_maxScroll > 0) ? (_currentScroll / _maxScroll) : 0;
            _scrollbarThumb.setPosition(barX, this.y + ratio * (_viewportH - thumbHeight));
        }
    }

    override public function destroy():Void
    {
        UiManager.unregister(this);
        super.destroy();
    }
}
