package menus.charting;

import backend.assets.FunkinSound;
import backend.assets.FunkinSprite;
import backend.assets.Paths;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.world.CharacterRegistry;
import backend.utils.MathUtil;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxBitmapText;
import flixel.util.FlxColor;

import game.ui.HealthIcon;

class CharterStrumlineBox extends FlxSpriteGroup
{
    public var entry:ChartStrumline;
    public var strumline:CharterStrumline;

    public var onEdit:Void->Void;
    public var interactable:Bool = true;

    public var hovered(default, null):Bool = false;

    var gridCamera:FlxCamera;
    var atlasFrames:FlxAtlasFrames;

    var bgSlices:Array<FunkinSprite> = [];
    var sliceLocalX:Array<Float> = [];
    var sliceLocalY:Array<Float> = [];

    var iconBox:FunkinSprite;
    var icon:CharterStrumIcon;
    var editButton:FunkinSprite;
    var roleIcon:FunkinSprite;
    var idText:FlxBitmapText;

    var originX:Float = 0;
    var originY:Float = 0;
    var builtWidth:Float = -1;

    var iconHover:Float = 0;
    var editHover:Bool = false;

    public function new(entry:ChartStrumline, strumline:CharterStrumline, gridCamera:FlxCamera, onEdit:Void->Void)
    {
        super();

        this.entry = entry;
        this.strumline = strumline;
        this.gridCamera = gridCamera;
        this.onEdit = onEdit;

        atlasFrames = Paths.getSparrowAtlas("menus/charter/box");

        iconBox = new FunkinSprite().makeGraphic(1, 1, 0xFF2B2B33);
        iconBox.origin.set(0, 0);
        iconBox.alpha = 0.5;

        icon = new CharterStrumIcon();

        editButton = new FunkinSprite().loadGraphic(Paths.image("menus/charter/editButton"));
        editButton.antialiasing = false;
        editButton.alpha = 0.55;

        roleIcon = new FunkinSprite();
        roleIcon.antialiasing = false;

        idText = new FlxBitmapText(0, 0, "", Paths.getAngelFont("jetbrains"));
        idText.scale.set(0.26, 0.26);
        idText.alpha = 0.6;

        rebuild();

        this.camera = gridCamera;
    }

    public function rebuild():Void
    {
        for (slice in bgSlices)
            slice.destroy();

        clear();

        bgSlices = [];
        sliceLocalX = [];
        sliceLocalY = [];

        builtWidth = strumline.width;

        var w:Float = builtWidth;
        var h:Float = 83;
        var c:Float = 10;

        var midW:Float = Math.max(0.1, w - (c * 2));
        var midH:Float = Math.max(0.1, h - (c * 2));

        addSlice("topleft", 0, 0, c, c);
        addSlice("top", c, 0, midW, c);
        addSlice("topright", w - c, 0, c, c);

        addSlice("middleleft", 0, c, c, midH);
        addSlice("middle", c, c, midW, midH);
        addSlice("middleright", w - c, c, c, midH);

        addSlice("bottomleft", 0, h - c, c, c);
        addSlice("bottom", c, h - c, midW, c);
        addSlice("bottomright", w - c, h - c, c, c);

        var inner:Float = 83 - (8 * 2);
        iconBox.setGraphicSize(inner, inner);
        iconBox.updateHitbox();
        add(iconBox);

        for (spr in icon.sprites())
            add(spr);

        editButton.setGraphicSize(22, 22);
        editButton.updateHitbox();
        add(editButton);

        add(roleIcon);
        add(idText);

        refresh();
        follow(originY, originY, 0);
    }

    function addSlice(name:String, lx:Float, ly:Float, w:Float, h:Float):Void
    {
        var slice = new FunkinSprite();
        slice.frames = atlasFrames;
        slice.animation.addByNames("idle", ["box-" + name], 1, false);
        slice.animation.play("idle");
        slice.origin.set(0, 0);
        slice.setGraphicSize(w, h);
        slice.updateHitbox();

        add(slice);

        bgSlices.push(slice);
        sliceLocalX.push(lx);
        sliceLocalY.push(ly);
    }

    public function refresh():Void
    {
        if (builtWidth != strumline.width)
        {
            rebuild();
            return;
        }

        icon.load(entry.character);

        var role:String = (entry.playable == true) ? "menus/charter/playerIcon" : "menus/charter/botIcon";
        roleIcon.loadGraphic(Paths.image(role));
        roleIcon.setGraphicSize(24, 24 * (roleIcon.frameHeight / roleIcon.frameWidth));
        roleIcon.updateHitbox();
        roleIcon.antialiasing = false;

        idText.text = "ID: " + (entry.id ?? 0);
        idText.scale.set(0.26, 0.26);
        idText.updateHitbox();

        tintBackground();
    }

    function tintBackground():Void
    {
        var health:FlxColor = healthColorOf(entry.character);
        var tint:FlxColor = FlxColor.interpolate(FlxColor.WHITE, health, 0.4);

        for (slice in bgSlices)
        {
            slice.color = tint;
            slice.alpha = 0.55;
        }
    }

    function healthColorOf(character:String):FlxColor
    {
        if (character == null || character == "") return FlxColor.WHITE;

        var data = CharacterRegistry.get(character);
        if (data == null || data.color == null) return FlxColor.WHITE;

        var parsed:Null<FlxColor> = FlxColor.fromString(data.color);
        return (parsed != null) ? parsed : FlxColor.WHITE;
    }

    public function follow(naturalY:Float, viewTop:Float, topMargin:Float):Void
    {
        originX = strumline.x;
        originY = Math.max(naturalY, viewTop + topMargin);

        reposition();
    }

    function reposition():Void
    {
        for (i in 0...bgSlices.length)
            bgSlices[i].setPosition(originX + sliceLocalX[i], originY + sliceLocalY[i]);

        var inner:Float = 83 - (8 * 2);

        iconBox.setPosition(originX + 8, originY + 8);
        icon.layout(iconBox.x, iconBox.y, inner, inner);

        editButton.setPosition(originX + strumline.width - 8 - 22, originY + 8);
        idText.setPosition(originX + strumline.width - 8 - idText.width, originY + 83 - 3 - idText.height);
        roleIcon.setPosition(originX + strumline.width - 8 - 24, idText.y - 24 - 3);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        icon.update(elapsed);

        hovered = false;
        editHover = false;

        var overIcon:Bool = false;

        if (interactable && visible)
        {
            hovered = FlxG.mouse.overlaps(this, gridCamera);
            overIcon = FlxG.mouse.overlaps(iconBox, gridCamera);
            editHover = FlxG.mouse.overlaps(editButton, gridCamera);

            if (FlxG.mouse.justPressed)
            {
                if (editHover && onEdit != null)
                    onEdit();
                else if (overIcon)
                    cycleIcon();
            }
        }

        iconHover = MathUtil.smoothLerpPrecision(iconHover, overIcon ? 1 : 0, elapsed, 0.12);

        iconBox.color = FlxColor.interpolate(0xFF2B2B33, 0xFF17171C, iconHover);
        icon.setColor(FlxColor.interpolate(0xFFFFFFFF, 0xFF888888, iconHover));

        editButton.alpha = editHover ? 1.0 : 0.55;
    }

    function cycleIcon():Void
    {
        icon.cycle();
        FunkinSound.playOnce(Paths.sound("menus/charter/notes/place"), 0.35);
    }

    override public function destroy():Void
    {
        icon = null;
        super.destroy();
    }
}

class CharterStrumIcon
{
    public var normalIcon:HealthIcon;
    public var pixelIcon:FunkinSprite;

    var character:String = "bf";
    var states:Array<String> = [];

    var boxX:Float = 0;
    var boxY:Float = 0;
    var boxW:Float = 1;
    var boxH:Float = 1;

    var phase:String = "NORMAL";
    var stateIndex:Int = 0;
    var stepsLeft:Int = 0;
    var pixelConfirmed:Bool = false;
    var hasPixel:Bool = false;

    public function new()
    {
        normalIcon = new HealthIcon();
        normalIcon.canUpdatePosition = false;
        normalIcon.canUpdateState = false;
        normalIcon.canUpdateOffsets = false;
        normalIcon.canBounce = false;

        pixelIcon = new FunkinSprite();
        pixelIcon.visible = false;
        pixelIcon.antialiasing = false;
    }

    public function sprites():Array<FlxSprite>
    {
        return [normalIcon, pixelIcon];
    }

    public function load(character:String):Void
    {
        this.character = (character != null && character != "") ? character : "bf";

        normalIcon.changeIcon(this.character);

        states = [];
        var data = normalIcon.data;
        if (data != null && data.states != null)
            for (s in data.states) states.push(s.name);

        if (states.length == 0) states = ["neutral"];

        hasPixel = Paths.exists('images/characters/${this.character}/icon-pixel.png');

        if (hasPixel)
        {
            pixelIcon.frames = Paths.getSparrowAtlas('characters/${this.character}/icon-pixel');
            pixelIcon.animation.addByPrefix("idle", "idle0", 10, true);
            pixelIcon.animation.addByPrefix("confirm", "confirm0", 10, false);
        }

        resetToStart();
    }

    function resetToStart():Void
    {
        phase = "NORMAL";
        pixelConfirmed = false;
        pixelIcon.visible = false;
        normalIcon.visible = true;

        stateIndex = states.indexOf("neutral");
        if (stateIndex < 0) stateIndex = states.length - 1;

        stepsLeft = states.length;

        showState(stateIndex);
    }

    public function cycle():Void
    {
        if (phase == "PIXEL")
        {
            if (!pixelConfirmed)
            {
                pixelConfirmed = true;
                pixelIcon.animation.play("confirm", true);
            }
            else
                resetToStart();

            return;
        }

        stepsLeft--;

        if (stepsLeft <= 0)
        {
            if (hasPixel)
                enterPixel();
            else
                resetToStart();

            return;
        }

        stateIndex = (stateIndex + 1) % states.length;
        showState(stateIndex);
    }

    function enterPixel():Void
    {
        phase = "PIXEL";
        pixelConfirmed = false;

        normalIcon.visible = false;
        pixelIcon.visible = true;
        pixelIcon.animation.play("idle", true);

        fit(pixelIcon);
    }

    function showState(index:Int):Void
    {
        if (index < 0 || index >= states.length) return;

        normalIcon.state = states[index];
        fit(normalIcon);
    }

    public function layout(x:Float, y:Float, w:Float, h:Float):Void
    {
        boxX = x;
        boxY = y;
        boxW = w;
        boxH = h;

        fit(phase == "PIXEL" ? pixelIcon : normalIcon);
    }

    function fit(spr:FlxSprite):Void
    {
        if (spr == null || spr.frameWidth <= 0 || spr.frameWidth <= 0) return;

        var inset:Float = 6.0;
        var scale:Float = Math.min((boxW - inset) / spr.frameWidth, (boxH - inset) / spr.frameHeight);
        if (scale <= 0) scale = 0.01;

        spr.scale.set(scale, scale);
        spr.updateHitbox();

        spr.setPosition(boxX + (boxW - spr.width) / 2, boxY + (boxH - spr.width) / 2);
    }

    public function setColor(value:FlxColor):Void
    {
        normalIcon.color = value;
        pixelIcon.color = value;
    }

    public function update(elapsed:Float):Void
    {
        fit(phase == "PIXEL" ? pixelIcon : normalIcon);
    }
}
