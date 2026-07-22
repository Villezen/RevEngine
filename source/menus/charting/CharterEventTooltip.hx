package menus.charting;

import backend.registries.song.EventObjectRegistry.EventObjectData;
import backend.utils.MathUtil;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxBitmapText;

class CharterEventTooltip extends FlxSpriteGroup
{
    static inline final WIDTH:Float = 230.0;
    static inline final PADDING:Float = 8.0;
    static inline final GAP:Float = 10.0;
    static inline final SLIDE:Float = 14.0;
    static inline final MAX_VARS:Int = 16;

    var _border:FunkinSprite;
    var _panel:FunkinSprite;

    var _titleText:FlxBitmapText;
    var _descText:FlxBitmapText;
    var _varLines:Array<FlxBitmapText> = [];
    var _usedLines:Int = 0;

    var _titleY:Float = 0;
    var _descY:Float = 0;
    var _varsY:Float = 0;
    var _lineHeight:Float = 0;
    var _panelHeight:Float = 0;

    var _shown:Bool = false;
    var _fade:Float = 0;
    var _slide:Float = SLIDE;

    var _currentEvent:CharterEvent;
    var _anchorX:Float = 0;
    var _anchorTopY:Float = 0;
    var _viewWidth:Float = 0;

    public function new()
    {
        super();

        _border = new FunkinSprite().makeGraphic(1, 1, 0xFFBCBCBC);
        _border.origin.set(0, 0);
        add(_border);

        _panel = new FunkinSprite().makeGraphic(1, 1, 0xFF16161C);
        _panel.origin.set(0, 0);
        add(_panel);

        _titleText = makeText("jetbrains/solid", 0.26, 0xFFFFFFFF, false);
        _descText = makeText("jetbrains", 0.19, 0xFFFFFFFF, true);

        for (i in 0...MAX_VARS)
            _varLines.push(makeText("jetbrains/solid", 0.2, 0xFF7FDBFF, false));

        visible = false;
    }

    function makeText(font:String, scale:Float, color:Int, wrap:Bool):FlxBitmapText
    {
        var text = new FlxBitmapText(0, 0, "", Paths.getAngelFont(font));
        text.scale.set(scale, scale);
        text.color = color;

        if (wrap)
        {
            text.autoSize = false;
            text.wordWrap = true;
            text.fieldWidth = Std.int((WIDTH - PADDING * 2) / scale);
        }

        text.updateHitbox();
        add(text);

        return text;
    }

    public function showAt(event:CharterEvent, data:EventObjectData, centerX:Float, aboveY:Float, viewWidth:Float):Void
    {
        if (event == null)
        {
            hide();
            return;
        }

        if (event != _currentEvent)
        {
            _currentEvent = event;
            setContent(event, data);
            measure();
        }

        _anchorX = centerX;
        _anchorTopY = aboveY;
        _viewWidth = viewWidth;
        _shown = true;
    }

    public function hide():Void
    {
        _shown = false;
        _currentEvent = null;
    }

    function setContent(event:CharterEvent, data:EventObjectData):Void
    {
        _titleText.text = (data != null && data.name != null) ? data.name : event.name;
        _titleText.updateHitbox();

        _descText.text = (data != null && data.description != null) ? data.description : "";
        _descText.updateHitbox();

        var defs = (data != null) ? data.variables : null;
        var count:Int = (defs != null) ? defs.length : event.variables.length;
        if (count > MAX_VARS) count = MAX_VARS;

        _usedLines = count;

        for (i in 0...MAX_VARS)
        {
            if (i < count)
            {
                var label:String = (defs != null && i < defs.length && defs[i] != null && defs[i].name != null) ? defs[i].name : ('Var ' + i);
                var value:String = (i < event.variables.length) ? event.variables[i] : "";

                _varLines[i].text = '$label: $value';
            }
            else
                _varLines[i].text = "";

            _varLines[i].updateHitbox();
        }
    }

    function measure():Void
    {
        _lineHeight = _varLines[0].height;

        var y:Float = PADDING;

        _titleY = y;
        y += _titleText.height + 5;

        if (_descText.text != "")
        {
            _descY = y;
            y += _descText.height + 7;
        }

        if (_usedLines > 0)
        {
            _varsY = y;
            y += _usedLines * _lineHeight;
        }

        _panelHeight = y + PADDING;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        _fade = MathUtil.smoothLerpPrecision(_fade, _shown ? 1.0 : 0.0, elapsed, 0.09);
        _slide = MathUtil.smoothLerpPrecision(_slide, _shown ? 0.0 : SLIDE, elapsed, 0.09);

        visible = _fade > 0.01;
        if (!visible) return;

        applyLayout();
    }

    function applyLayout():Void
    {
        var px:Float = _anchorX - (WIDTH / 2);

        if (px < 4) px = 4;
        if (px > _viewWidth - WIDTH - 4) px = _viewWidth - WIDTH - 4;

        var py:Float = (_anchorTopY - _panelHeight - GAP) + _slide;

        _border.setGraphicSize(WIDTH + 2, _panelHeight + 2);
        _border.updateHitbox();
        _border.setPosition(px - 1, py - 1);
        _border.alpha = 0.4 * _fade;

        _panel.setGraphicSize(WIDTH, _panelHeight);
        _panel.updateHitbox();
        _panel.setPosition(px, py);
        _panel.alpha = 0.92 * _fade;

        _titleText.setPosition(px + PADDING, py + _titleY);
        _titleText.alpha = _fade;

        _descText.setPosition(px + PADDING, py + _descY);
        _descText.alpha = 0.7 * _fade;

        for (i in 0..._varLines.length)
        {
            if (i < _usedLines)
            {
                _varLines[i].setPosition(px + PADDING, py + _varsY + (i * _lineHeight));
                _varLines[i].alpha = _fade;
            }
            else
                _varLines[i].alpha = 0;
        }
    }
}
