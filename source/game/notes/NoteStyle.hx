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

        var isEK = KeyUtil.isEK(this.keys);
        var path = strum.data.type == "SEPARATE" ? 'game/notes/styles/${this.name}/strumline' : 'game/notes/styles/${this.name}/skin';

        if (!loadTexture(strum, path, strum.data.type, strum.data.textureBox))
            return;

        var anims:Array<BaseAnimationData> = isEK ? strum.data.animations.extraKeys : strum.data.animations.normal;
        
        var baseColor = (isEK ? Constants.COLOR_DIRECTIONS[this.keys][strum.direction] : Constants.DIRECTIONS[this.keys][strum.direction]).toUpperCase();
        var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][strum.direction].toUpperCase();

        var statBase = 'static$baseColor';
        var presBase = 'pressed$baseColor';
        var confBase = 'confirm$baseColor';

        var statBind = 'static$bindColor';
        var presBind = 'pressed$bindColor';
        var confBind = 'confirm$bindColor';

        for (anim in anims)
        {
            var isArray:Bool = Std.isOfType(anim.prefix, Array);
            var prefixStr:String = isArray ? "" : Std.string(anim.prefix);
            var isBind:Bool = !isArray && prefixStr.indexOf("keybind[") != -1;
            
            var tStat = isBind ? statBind : statBase;
            var tPres = isBind ? presBind : presBase;
            var tConf = isBind ? confBind : confBase;

            if (strum.data.type == "TEXTURE" && isArray)
            {
                var framesArray:Array<Int> = cast anim.prefix;
                
                if (anim.name == tStat)
                    strum.animation.add('static', framesArray, anim.fps);
                else if (anim.name == tPres)  
                    strum.animation.add('pressed', framesArray, anim.fps, false);
                else if (anim.name == tConf) 
                    strum.animation.add('confirm', framesArray, anim.fps, false);
            }
            else if (!isArray)
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

        var isEK = KeyUtil.isEK(this.keys);
        var path = note.parent.data.type == "SEPARATE" ? 'game/notes/styles/${this.name}/notes' : 'game/notes/styles/${this.name}/skin';

        if (!loadTexture(note, path, note.parent.data.type, note.parent.data.textureBox))
            return;

        var anims:Array<BaseAnimationData> = isEK ? note.parent.data.animations.extraKeys : note.parent.data.animations.normal;
        
        var baseColor = (isEK ? Constants.COLOR_DIRECTIONS[this.keys][note.direction] : Constants.DIRECTIONS[this.keys][note.direction]).toUpperCase();
        var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][note.direction].toUpperCase();

        var arrowBase = 'arrow$baseColor';
        var arrowBind = 'arrow$bindColor';

        for (anim in anims)
        {
            var isArray:Bool = Std.isOfType(anim.prefix, Array);
            var prefixStr:String = isArray ? "" : Std.string(anim.prefix);
            var isBind:Bool = !isArray && prefixStr.indexOf("keybind[") != -1;
            
            var targetName = isBind ? arrowBind : arrowBase;

            if (anim.name == targetName)
            {
                if (note.parent.data.type == "TEXTURE" && isArray)
                {
                    var framesArray:Array<Int> = cast anim.prefix;
                    note.animation.add('scroll', framesArray, anim.fps);
                }
                else if (!isArray)
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

        var isEK = KeyUtil.isEK(this.keys);
        var path = sustain.strum.data.type == "SEPARATE" ? 'game/notes/styles/${this.name}/sustains' : 'game/notes/styles/${this.name}/skin';

        if (!Paths.exists('images/$path.png'))
            return;

        if (sustain.strum.data.type == "SEPARATE")
        {
            var graphic = FlxG.bitmap.add(Paths.image(path));
            if (graphic == null) return;

            sustain.loadGraphic(graphic, true, Std.int(graphic.width / (isEK ? 18 : 8)), Std.int(graphic.height));
        }
        else if (sustain.strum.data.type == "TEXTURE")
        {
            var graphic = FlxG.bitmap.add(Paths.image(path));
            if (graphic == null) return;
            
            sustain.loadGraphic(graphic, true, sustain.strum.data.textureBox[0], sustain.strum.data.textureBox[1]);
        }
        else 
            sustain.frames = Paths.getSparrowAtlas(path);

        var anims:Array<BaseAnimationData> = isEK ? sustain.strum.data.animations.extraKeys : sustain.strum.data.animations.normal;
        
        var baseColor = (isEK ? Constants.COLOR_DIRECTIONS[this.keys][sustain.direction] : Constants.DIRECTIONS[this.keys][sustain.direction]).toUpperCase();
        var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][sustain.direction].toUpperCase();

        var holdBase = 'hold$baseColor';
        var tailBase = 'tail$baseColor';
        var holdBind = 'hold$bindColor';
        var tailBind = 'tail$bindColor';

        for (anim in anims)
        {
            var isArray:Bool = Std.isOfType(anim.prefix, Array);
            var prefixStr:String = isArray ? "" : Std.string(anim.prefix);
            var isBind:Bool = !isArray && prefixStr.indexOf("keybind[") != -1;

            var tHold = isBind ? holdBind : holdBase;
            var tTail = isBind ? tailBind : tailBase;

            if (sustain.strum.data.type == "SEPARATE")
            {
                sustain.animation.add('hold', [sustain.direction * 2], anim.fps);
                sustain.animation.add('tail', [(sustain.direction * 2) + 1], anim.fps);
            }
            else if (sustain.strum.data.type == "TEXTURE" && isArray)
            {
                var framesArray:Array<Int> = cast anim.prefix;

                if (anim.name == 'hold' || anim.name == tHold)
                    sustain.animation.add('hold', framesArray, anim.fps);
                else if (anim.name == 'tail' || anim.name == tTail)
                    sustain.animation.add('tail', framesArray, anim.fps);
            }
            else if (!isArray)
            {
                var finalPrefix = isBind ? KeyUtil.formatNoteBind(prefixStr, this.keys) : prefixStr;

                if (anim.name == 'hold' || anim.name == tHold)
                    sustain.animation.addByPrefix('hold', finalPrefix, anim.fps);
                else if (anim.name == 'tail' || anim.name == tTail)
                    sustain.animation.addByPrefix('tail', finalPrefix, anim.fps);
            }
        }
        
        sustain.antialiasing = sustain.strum.data.antialiasing;
    }

    public function applyToSplash(splash:NoteSplash)
    {
        if (splash == null || splash.data == null) return;

        splash.animation.destroyAnimations();
        splash.animation.reset();

        var isEK = KeyUtil.isEK(this.keys);
        var basePath = 'game/notes/splashes/${this.name}';
        
        var colDir:String = (isEK ? Constants.COLOR_DIRECTIONS[this.keys][splash.direction] : Constants.DIRECTIONS[this.keys][splash.direction]);
        var path = splash.data.type == "SEPARATE" ? '$basePath/$colDir' : '$basePath/skin';

        if (!loadTexture(splash, path, splash.data.type, splash.data.textureBox))
            return;

        if (splash.data.animations != null)
        {
            var anims:Array<BaseAnimationData> = isEK ? splash.data.animations.extraKeys : splash.data.animations.normal;
            
            var baseColor = colDir.toUpperCase();
            var bindColor = Constants.DIRECTIONS_KEYBIND[this.keys][splash.direction].toUpperCase();
            
            for (anim in anims)
            {
                var isArray:Bool = Std.isOfType(anim.prefix, Array);
                var prefixStr:String = isArray ? "" : Std.string(anim.prefix);
                var isBind:Bool = !isArray && prefixStr.indexOf("keybind[") != -1;
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
                    if (splash.data.type == "TEXTURE" && isArray)
                    {
                        var framesArray:Array<Int> = cast anim.prefix;
                        splash.animation.add(targetName, framesArray, anim.fps, false);
                    }
                    else if (!isArray)
                    {
                        splash.animation.addByPrefix(targetName, finalPrefix, anim.fps, false);
                    }
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

        var isEK = KeyUtil.isEK(this.keys);
        var basePath = 'game/notes/covers/${this.name}';
        var colDir:String = (isEK ? Constants.COLOR_DIRECTIONS[this.keys][cover.direction] : Constants.DIRECTIONS[this.keys][cover.direction]);
        
        var path = cover.data.type == "SEPARATE" ? '$basePath/$colDir' : '$basePath/skin';

        if (!loadTexture(cover, path, cover.data.type, cover.data.textureBox))
            return;

        if (cover.data.animations != null)
        {
            var anims:Array<BaseAnimationData> = isEK ? cover.data.animations.extraKeys : cover.data.animations.normal;
            
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
                var isArray:Bool = Std.isOfType(anim.prefix, Array);
                var prefixStr:String = isArray ? "" : Std.string(anim.prefix);
                var isBind:Bool = !isArray && prefixStr.indexOf("keybind[") != -1;

                var tStart = isBind ? startBind : startBase;
                var tLoop = isBind ? loopBind : loopBase;
                var tEnd = isBind ? endBind : endBase;
                
                if (cover.data.type == "TEXTURE" && isArray)
                {
                    var framesArray:Array<Int> = cast anim.prefix;

                    if (anim.name == 'start' || anim.name == tStart)
                        cover.animation.add('start', framesArray, anim.fps, false);
                    else if (anim.name == 'loop' || anim.name == tLoop)
                        cover.animation.add('loop', framesArray, anim.fps, true);
                    else if (anim.name == 'end' || anim.name == tEnd)
                        cover.animation.add('end', framesArray, anim.fps, false);
                }
                else if (!isArray)
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