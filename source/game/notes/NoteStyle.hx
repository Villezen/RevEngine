package game.notes;

import backend.registries.ui.NoteSkinRegistry.BaseAnimationData;
import backend.utils.KeyUtil;

/**
 * Parameters used to initialize a specific note style.
 */
typedef NoteStyleParams = 
{
    /**
     * Name of the skin.
     */
    var name:String;

    /**
     * The key count of the strumline itself.
     */
    var keys:Int;
}

/**
 * An abstract wrapper that provides methods to apply textures and animations to gameplay objects.
 */
@:forward
abstract NoteStyle(NoteStyleParams) from NoteStyleParams to NoteStyleParams
{
    static function resolveTexturePath(base:String, suffix:String):String
    {
        if (suffix != "" && Paths.exists('images/$base$suffix.png'))
            return '$base$suffix';

        if (Paths.exists('images/$base.png'))
            return base;

        return null;
    }

    static function loadTexture(sprite:FunkinSprite, path:String, type:String, textureBox:Array<Int>):Bool
    {
        if (!Paths.exists('images/$path.png'))
            return false;

        if (type == "TEXTURE")
        {
            var graphic = FlxG.bitmap.add(Paths.image(path));
            if (graphic == null) return false;

            sprite.loadGraphic(graphic, true, textureBox[0], textureBox[1]);
        }
        else
            sprite.frames = Paths.getSparrowAtlas(path);

        return true;
    }

    public function applyToStrum(strum:Strum)
    {
        if (strum == null || strum.data == null) return;

        strum.animation.destroyAnimations();
        strum.animation.reset();

        var isMultiKey = KeyUtil.isMultiKey(this.keys);
        var suffix = isMultiKey ? '-multikey' : '';
        var path = resolveTexturePath(strum.data.type == "COMBINED" ? 'game/notes/styles/${this.name}/skin' : 'game/notes/styles/${this.name}/strumline', suffix);

        if (path == null || !loadTexture(strum, path, strum.data.type, strum.data.textureBox))
            return;

        var anims:Array<BaseAnimationData> = isMultiKey ? strum.data.animations.multikeys : strum.data.animations.normal;
        
        var baseColor = (isMultiKey ? Constants.COLOR_DIRECTIONS[this.keys][strum.direction] : Constants.DIRECTIONS[this.keys][strum.direction]).toUpperCase();
        var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][strum.direction].toUpperCase();

        var statBase = 'static$baseColor';
        var presBase = 'pressed$baseColor';
        var confBase = 'confirm$baseColor';

        var statBind = 'static$bindColor';
        var presBind = 'pressed$bindColor';
        var confBind = 'confirm$bindColor';

        for (anim in anims)
        {
            var hasFrames:Bool = anim.frames != null && anim.frames.length > 0;
            var prefixStr:String = hasFrames ? "" : Std.string(anim.prefix);
            var isBind:Bool = !hasFrames && prefixStr.indexOf("keybind[") != -1;

            var tStat = isBind ? statBind : statBase;
            var tPres = isBind ? presBind : presBase;
            var tConf = isBind ? confBind : confBase;

            if (strum.data.type == "TEXTURE" && hasFrames)
            {
                if (anim.name == tStat)
                    strum.animation.add('static', anim.frames, anim.fps);
                else if (anim.name == tPres)
                    strum.animation.add('pressed', anim.frames, anim.fps, false);
                else if (anim.name == tConf)
                    strum.animation.add('confirm', anim.frames, anim.fps, false);
            }
            else if (!hasFrames)
            {
                var finalPrefix = isBind ? KeyUtil.formatNoteBind(prefixStr, this.keys) : prefixStr;

                if (anim.name == tStat)
                    strum.animation.addByPrefix('static', finalPrefix, anim.fps);
                else if (anim.name == tPres)  
                    strum.animation.addByPrefix('pressed', finalPrefix, anim.fps, false);
                else if (anim.name == tConf) 
                    strum.animation.addByPrefix('confirm', finalPrefix, anim.fps, false);
            }
        }

        strum.scale.set(strum.data.strumSize * KeyUtil.getKeyScaleOffset(this.keys), strum.data.strumSize * KeyUtil.getKeyScaleOffset(this.keys));
        strum.antialiasing = strum.data.antialiasing;
        strum.updateHitbox();

        if (strum.animation.getByName('static') != null)
            strum.animation.play('static', true);
    }

    public function applyToNote(note:Note)
    {
        if (note == null || note.parent == null || note.parent.data == null) return;

        note.animation.destroyAnimations();
        note.animation.reset();

        var isMultiKey = KeyUtil.isMultiKey(this.keys);
        var suffix = isMultiKey ? '-multikey' : '';

        var path:String;
        if (note.parent.data.type == "COMBINED")
            path = resolveTexturePath('game/notes/styles/${this.name}/skin', suffix);
        else
        {
            path = resolveTexturePath('game/notes/styles/${this.name}/notes', suffix);

            if (path == null)
                path = resolveTexturePath('game/notes/styles/${this.name}/strumline', suffix);
        }

        if (path == null || !loadTexture(note, path, note.parent.data.type, note.parent.data.textureBox))
            return;

        var anims:Array<BaseAnimationData> = isMultiKey ? note.parent.data.animations.multikeys : note.parent.data.animations.normal;

        var baseColor = (isMultiKey ? Constants.COLOR_DIRECTIONS[this.keys][note.direction] : Constants.DIRECTIONS[this.keys][note.direction]).toUpperCase();
        var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][note.direction].toUpperCase();

        var arrowBase = 'arrow$baseColor';
        var arrowBind = 'arrow$bindColor';

        for (anim in anims)
        {
            var hasFrames:Bool = anim.frames != null && anim.frames.length > 0;
            var prefixStr:String = hasFrames ? "" : Std.string(anim.prefix);
            var isBind:Bool = !hasFrames && prefixStr.indexOf("keybind[") != -1;

            var targetName = isBind ? arrowBind : arrowBase;

            if (anim.name == targetName)
            {
                if (note.parent.data.type == "TEXTURE" && hasFrames)
                    note.animation.add('scroll', anim.frames, anim.fps);
                else if (!hasFrames)
                {
                    var finalPrefix = isBind ? KeyUtil.formatNoteBind(prefixStr, this.keys) : prefixStr;
                    note.animation.addByPrefix('scroll', finalPrefix, anim.fps);
                }
            }
        }

        note.antialiasing = note.parent.data.antialiasing;
        note.scale.set(note.parent.data.noteSize * KeyUtil.getKeyScaleOffset(this.keys), note.parent.data.noteSize * KeyUtil.getKeyScaleOffset(this.keys));
        note.updateHitbox();

        if (note.animation.getByName('scroll') != null)
            note.animation.play('scroll', true);
    }

    public function applyToSustain(sustain:SustainNote)
    {
        if (sustain == null || sustain.strum == null || sustain.strum.data == null) return;

        sustain.animation.destroyAnimations();
        sustain.animation.reset();

        var isMultiKey = KeyUtil.isMultiKey(this.keys);
        var suffix = isMultiKey ? '-multikey' : '';
        var isCombined = sustain.strum.data.type == "COMBINED";
        var base = isCombined ? 'game/notes/styles/${this.name}/skin' : 'game/notes/styles/${this.name}/sustains';

        var path = resolveTexturePath(base, suffix);
        if (path == null) return;

        var usedMultiKey = path.endsWith('-multikey');

        if (!isCombined)
        {
            var graphic = FlxG.bitmap.add(Paths.image(path));
            if (graphic == null) return;

            var columns:Int = usedMultiKey ? 18 : 8;
            sustain.loadGraphic(graphic, true, Std.int(graphic.width / columns), Std.int(graphic.height));

            var frameIndex:Int = sustain.direction;
            var palette:Array<String> = usedMultiKey ? Constants.COLOR_DIRECTIONS[this.keys] : Constants.DIRECTIONS[this.keys];
            var order:Array<String> = usedMultiKey ? Constants.COLOR_DIRECTIONS[9] : Constants.DIRECTIONS[4];

            if (palette != null && order != null && sustain.direction < palette.length)
            {
                var sheetIndex:Int = order.indexOf(palette[sustain.direction]);
                if (sheetIndex != -1) frameIndex = sheetIndex;
            }

            if (frameIndex < 0 || (frameIndex * 2) + 1 >= columns)
                frameIndex = 0;

            sustain.animation.add('hold', [frameIndex * 2], 24);
            sustain.animation.add('tail', [(frameIndex * 2) + 1], 24);
        }
        else
        {
            sustain.frames = Paths.getSparrowAtlas(path);

            var anims:Array<BaseAnimationData> = isMultiKey ? sustain.strum.data.animations.multikeys : sustain.strum.data.animations.normal;
            var baseColor = (isMultiKey ? Constants.COLOR_DIRECTIONS[this.keys][sustain.direction] : Constants.DIRECTIONS[this.keys][sustain.direction]).toUpperCase();

            for (anim in anims)
            {
                if (anim.frames != null && anim.frames.length > 0) continue;

                if (anim.name == 'hold' || anim.name == 'hold$baseColor')
                    sustain.animation.addByPrefix('hold', Std.string(anim.prefix), anim.fps);
                else if (anim.name == 'tail' || anim.name == 'tail$baseColor')
                    sustain.animation.addByPrefix('tail', Std.string(anim.prefix), anim.fps);
            }
        }

        sustain.antialiasing = sustain.strum.data.antialiasing;
    }

    public function applyToSplash(splash:NoteSplash)
    {
        if (splash == null || splash.data == null) return;

        splash.animation.destroyAnimations();
        splash.animation.reset();

        var isMultiKey = KeyUtil.isMultiKey(this.keys);
        var basePath = 'game/notes/splashes/${this.name}';
        var suffix = isMultiKey ? '-multikey' : '';

        var colDir:String = (isMultiKey ? Constants.COLOR_DIRECTIONS[this.keys][splash.direction] : Constants.DIRECTIONS[this.keys][splash.direction]);
        var path = splash.data.type == "SEPARATE" ? '$basePath/$colDir' : resolveTexturePath('$basePath/skin', suffix);

        if (path == null || !loadTexture(splash, path, splash.data.type, splash.data.textureBox))
            return;

        if (splash.data.animations != null)
        {
            var anims:Array<BaseAnimationData> = isMultiKey ? splash.data.animations.multikeys : splash.data.animations.normal;
            
            var baseColor = colDir.toUpperCase();
            var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][splash.direction].toUpperCase();
            
            for (anim in anims)
            {
                var hasFrames:Bool = anim.frames != null && anim.frames.length > 0;
                var prefixStr:String = hasFrames ? "" : Std.string(anim.prefix);
                var isBind:Bool = !hasFrames && prefixStr.indexOf("keybind[") != -1;
                var finalPrefix = isBind ? KeyUtil.formatNoteBind(prefixStr, this.keys) : prefixStr;

                var name = anim.name;
                var targetName = "";

                if (name.endsWith(baseColor)) 
                {
                    var potentialNum = name.substring(0, name.length - baseColor.length);

                    if (Std.string(Std.parseInt(potentialNum)) == potentialNum) 
                        targetName = potentialNum;
                }
                else if (name.endsWith(bindColor)) 
                {
                    var potentialNum = name.substring(0, name.length - bindColor.length);

                    if (Std.string(Std.parseInt(potentialNum)) == potentialNum) 
                        targetName = potentialNum;
                }
                else if (Std.string(Std.parseInt(name)) == name) 
                    targetName = name;

                if (targetName != "")
                {
                    if (splash.data.type == "TEXTURE" && hasFrames)
                        splash.animation.add(targetName, anim.frames, anim.fps, false);
                    else if (!hasFrames)
                        splash.animation.addByPrefix(targetName, finalPrefix, anim.fps, false);
                }
            }

            splash.antialiasing = splash.data.antialiasing;

            if (splash.data.size != null && splash.data.size.length >= 2)
                splash.scale.set(splash.data.size[0] * KeyUtil.getKeyScaleOffset(this.keys), splash.data.size[1] * KeyUtil.getKeyScaleOffset(this.keys));
        }
        else
            splash.scale.set(KeyUtil.getKeyScaleOffset(this.keys), KeyUtil.getKeyScaleOffset(this.keys));

        splash.updateHitbox();
    }

    public function applyToCover(cover:HoldCover)
    {
        if (cover == null || cover.data == null) return;

        cover.animation.destroyAnimations();
        cover.animation.reset();

        var isMultiKey = KeyUtil.isMultiKey(this.keys);
        var basePath = 'game/notes/covers/${this.name}';
        var suffix = isMultiKey ? '-multikey' : '';
        var colDir:String = Constants.COLOR_DIRECTIONS[this.keys][cover.direction];

        var path = cover.data.type == "SEPARATE" ? '$basePath/$colDir' : resolveTexturePath('$basePath/skin', suffix);

        if (path == null || !loadTexture(cover, path, cover.data.type, cover.data.textureBox))
            return;

        if (cover.data.animations != null)
        {
            var anims:Array<BaseAnimationData> = isMultiKey ? cover.data.animations.multikeys : cover.data.animations.normal;
            
            var baseColor = colDir.toUpperCase();
            var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][cover.direction].toUpperCase();

            var startBase = 'start$baseColor';
            var loopBase = 'loop$baseColor';
            var endBase = 'end$baseColor';

            var startBind = 'start$bindColor';
            var loopBind = 'loop$bindColor';
            var endBind = 'end$bindColor';

            for (anim in anims)
            {
                var hasFrames:Bool = anim.frames != null && anim.frames.length > 0;
                var prefixStr:String = hasFrames ? "" : Std.string(anim.prefix);
                var isBind:Bool = !hasFrames && prefixStr.indexOf("keybind[") != -1;

                var tStart = isBind ? startBind : startBase;
                var tLoop = isBind ? loopBind : loopBase;
                var tEnd = isBind ? endBind : endBase;

                if (cover.data.type == "TEXTURE" && hasFrames)
                {
                    if (anim.name == 'start' || anim.name == tStart)
                        cover.animation.add('start', anim.frames, anim.fps, false);
                    else if (anim.name == 'loop' || anim.name == tLoop)
                        cover.animation.add('loop', anim.frames, anim.fps, true);
                    else if (anim.name == 'end' || anim.name == tEnd)
                        cover.animation.add('end', anim.frames, anim.fps, false);
                }
                else if (!hasFrames)
                {
                    var finalPrefix = isBind ? KeyUtil.formatNoteBind(prefixStr, this.keys) : prefixStr;

                    if (anim.name == 'start' || anim.name == tStart)
                        cover.animation.addByPrefix('start', finalPrefix, anim.fps, false);
                    else if (anim.name == 'loop' || anim.name == tLoop)
                        cover.animation.addByPrefix('loop', finalPrefix, anim.fps, true);
                    else if (anim.name == 'end' || anim.name == tEnd)
                        cover.animation.addByPrefix('end', finalPrefix, anim.fps, false);
                }
            }

            cover.antialiasing = cover.data.antialiasing;

            if (cover.data.size != null && cover.data.size.length >= 2)
                cover.scale.set(cover.data.size[0] * KeyUtil.getKeyScaleOffset(this.keys), cover.data.size[1] * KeyUtil.getKeyScaleOffset(this.keys));
        }
        else
        {
            cover.scale.set(KeyUtil.getKeyScaleOffset(this.keys), KeyUtil.getKeyScaleOffset(this.keys));
        }

        cover.updateHitbox();
    }
}