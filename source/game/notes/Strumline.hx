package game.notes;

import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;

import flixel.animation.FlxAnimation;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;

import backend.registries.ui.NoteSkinRegistry;

import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.ChartRegistry.ChartNote;

import backend.utils.KeyUtil;

/**
 * Parameters used to initialize the instance.
 */
typedef StrumlineParams =
{
    var data:ChartStrumline;
    var cpu:Bool;
    var skin:String;
    var ?scale:Float;
}

/**
 * A snapshot of a sprite's current animation.
 */
typedef AnimState =
{
    var name:String;
    var frame:Int;
    var visible:Bool;
}

/**
 * A complex sprite group that handles strum receptors and scrolling notes.
 */
@:access(game.notes)
class Strumline extends FlxSpriteGroup    
{
    /**
     * Signal dispatched when a note is hit.
     */
    public var onNoteHit(default, null):FlxTypedSignal<Note->Void> = new FlxTypedSignal<Note->Void>();

    /**
     * Signal dispatched when a sustain is continuously being pressed.
     */
    public var onSustainHit(default, null):FlxTypedSignal<SustainNote->Void> = new FlxTypedSignal<SustainNote->Void>();

    /**
     * Signal dispatched when a note is missed.
     */
    public var onNoteMiss(default, null):FlxTypedSignal<Note->Void> = new FlxTypedSignal<Note->Void>();

    /**
     * Reference to the original parameteres used to create this strumline.
     */
    public var params:StrumlineParams;

    /**
     * Caches skins to prevent issues with note recycling.
     */
    private var _cachedSkinA:{name:String, keys:Int} = {name: "default", keys: 4};
    private var _cachedSkinB:{name:String, keys:Int} = {name: "default", keys: 4};

    private var _toggleSkin:Bool = false;

    inline function getSkinParams():{name:String, keys:Int}
    {
        _toggleSkin = !_toggleSkin;
        return _toggleSkin ? _cachedSkinA : _cachedSkinB;
    }

    /**
     * A pre-allocated array used to prevent memory spikes when filtering hittable notes.
     */
    private var _hittableNotesCache:Array<Note> = [];

    /**
     * The strumline's skin.
     */
    public var skin(default, set):String = "default";

    /**
     * The skin to actually render with. Skins for example that don't have a multikey variant and should load it will just resort them to the default skin.
     * @param name The requested skin.
     * @param keys The strumline's key count.
     * @return The skin name to use.
     */
    function resolveEffectiveSkin(name:String, keys:Int):String
    {
        if (name == "default" || !KeyUtil.isMultiKey(keys))
            return name;

        if (Paths.exists('images/game/notes/styles/$name/strumline-multikey.png') || Paths.exists('images/game/notes/styles/$name/skin-multikey.png'))
            return name;

        return "default";
    }

    function set_skin(value:String):String
    {
        skin = value;

        var effectiveSkin:String = resolveEffectiveSkin(skin, keyCount);

        _cachedSkinA.name = effectiveSkin;
        _cachedSkinB.name = effectiveSkin;

        _cachedSkinA.keys = keyCount;
        _cachedSkinB.keys = keyCount;

        if (strums.length == 0 || inIntro)
            return skin;

        reload_strums();

        for (note in notes.members)
        {
            if (note == null || !note.alive) continue;

            if (note.direction < keyCount)
            {
                note.parent = strums.members[note.direction];
                note.skin = getSkinParams();
                invalidateScale(note);
                note.sync();

                applyScale(note);
            }
            else
            {
                note.parent = null;
                note.visible = false;
            }
        }

        for (sustain in sustains.members)
        {
            if (sustain == null || !sustain.exists || !sustain.alive) continue;

            if (sustain.direction < keyCount)
            {
                sustain.strum = strums.members[sustain.direction];
                sustain.skin = getSkinParams();
                invalidateScale(sustain);
            }
        }

        reload_splashes();
        reload_covers();

        return skin;
    }

    /**
     * If checked, will flip the notes to it's Y axis to ensure everything is rendered correctly with a flipped camera.
     */
    public var downScroll(default, set):Bool = false;

    function set_downScroll(value:Bool):Bool
    {
        downScroll = value;

        if (strums.members.length > 0)
        {
            for (strum in strums.members)
            {
                if (strum == null) continue;

                strum.sync();
            }
        }

        return downScroll;
    }

    /**
     * The custom scale multiplier applied to this strumline.
     */
    public var scaleMult(default, set):Float = 1.0;

    function set_scaleMult(value:Float):Float
    {
        scaleMult = value;
        
        if (strums != null && strums.length > 0)
        {
            reload_strums();
            
            for (note in notes.members)
            {
                if (note != null && note.direction < keyCount)
                {
                    note.parent = strums.members[note.direction];
                    applyScale(note);
                }
            }

            for (sustain in sustains.members)
            {
                if (sustain != null && sustain.direction < keyCount)
                {
                    sustain.strum = strums.members[sustain.direction];
                    applyScale(sustain, true);
                }
            }

            for (splash in splashes.members)
            {
                if (splash != null && splash.direction < keyCount)
                {
                    splash.parent = strums.members[splash.direction];
                    applyScale(splash);
                }
            }

            for (cover in covers.members)
            {
                if (cover != null && cover.direction < keyCount)
                {
                    cover.parent = strums.members[cover.direction];
                    applyScale(cover);
                }
            }
        }

        return scaleMult;
    }

    /**
     * Cache to remember the original scale of sprites before they get affected by the scale multiplier.
     */
    private var _originalScales:Map<FunkinSprite, FlxPoint> = new Map<FunkinSprite, FlxPoint>();

    public var hasSplashes:Bool = false;
    public var hasCovers:Bool = false;

    /**
     * The amount of receptorsin the strumline.
     */
    public var keyCount(default, set):Int = 4;

    function set_keyCount(value:Int):Int
    {        
        keyCount = value;

        if (keyCount > 9)
            keyCount = 9;
        else if (keyCount < 1)
            keyCount = 1;

        var effectiveSkin:String = resolveEffectiveSkin(skin, keyCount);

        _cachedSkinA.name = effectiveSkin;
        _cachedSkinB.name = effectiveSkin;

        _cachedSkinA.keys = keyCount;
        _cachedSkinB.keys = keyCount;

        if (inIntro)
            return keyCount;

        for (note in notes.members)
        {
            if (note != null)
                note.parent = null;
        }

        for (sustain in sustains.members)
        {
            if (sustain != null)
            {
                sustain.strum = null;
                sustain.visible = false;
            }
        }

        reload_strums();
        reload_splashes();
        reload_covers();

        if (!cpu)
            PlayState.instance?.inputs?.setup(keyCount);

        for (note in notes.members)
        {
            if (note == null || !note.alive) continue;

            if (note.direction < keyCount)
            {
                note.parent = strums.members[note.direction];
                note.skin = getSkinParams();
                invalidateScale(note);
            }
            else
            {
                note.parent = null;
                note.visible = false;
            }
        }

        for (sustain in sustains.members)
        {
            if (sustain == null || !sustain.exists || !sustain.alive) continue;

            if (sustain.direction < keyCount)
            {
                sustain.strum = strums.members[sustain.direction];
                sustain.skin = getSkinParams();
                invalidateScale(sustain);
                sustain.visible = true;
            }
        }

        return keyCount;
    }

    /**
     * Wheter the strumline should be controlled by a bot.  
     */
    public var cpu:Bool = false;

    /**
     * Identifier for this strumline.
     */
    public var id:Int = 0;

    /**
     * Scroll speed multiplier for the notes.
     */
    public var speed:Float = 1.0;

    /**
     * Group containing the static receptors.
     */
    public var strums(default, null):FlxTypedSpriteGroup<Strum>;

    /**
     * Group containing the active scrolling notes.
     */
    public var notes(default, null):FlxTypedSpriteGroup<Note>;

    /**
     * Group containing sustain notes.
     */
    public var sustains(default, null):FlxTypedSpriteGroup<SustainNote>;

    /**
     * Group containing all note splashes.
     */
    public var splashes(default, null):FlxTypedSpriteGroup<NoteSplash>;

    /**
     * Group containing all hold covers.
     */
    public var covers(default, null):FlxTypedSpriteGroup<HoldCover>;

    /**
     * Local copy of the chart's raw data.
     */
    private var _noteList(default, null):Array<ChartNote> = [];

    /**
     * Tracking index to know which note in `_noteList` should be spawned.
     */
    private var _currentNoteIndex:Int = 0;

    /**
     * Timers used to track the 'confirm' state of the receptors when notes are hit.
     */
    public var strumGlowTimers:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    /**
     * Wheater the strum receptors with a higher key count than 4 should have their X axis aligned in order to be centered properly. Disable this if you're adding strumlines in the game camera.
     */
    public var alignStrums:Bool = true;

    /**
     * Mapping of the currently held note directions.
     */
    private var _heldKeys:Array<Bool> = [];

    /**
     * Disables key and skin switching during the intro animation.
     */
    public var inIntro:Bool = false;

    /**
     * Creates a new Strumline.
     * @param x The base X position.
     * @param y The base Y position.
     * @param params Configuration parameteres.
     */
    public function new(x:Float, y:Float, params:StrumlineParams)
    {
        super(x, y);

        strums = new FlxTypedSpriteGroup<Strum>(0, 0);
        notes = new FlxTypedSpriteGroup<Note>(0, 0);
        sustains = new FlxTypedSpriteGroup<SustainNote>(0, 0);
        covers = new FlxTypedSpriteGroup<HoldCover>(0, 0);
        splashes = new FlxTypedSpriteGroup<NoteSplash>(0, 0);

        downScroll = Configs.DOWNSCROLL;

        this.params = params;

        this.id = params.data.id;
        this.speed = params.data.speed;
        this.cpu = params.cpu;
        this.scaleMult = params.scale != null ? params.scale : 1.0;
        this.skin = params.skin;
        this.keyCount = params.data.keys;

        setup_notes();

        add(strums);
        add(sustains);
        add(notes);
        add(covers);
        add(splashes);
    }

    /**
     * Spawns incoming notes and calculates positions for active ones, alongside other things.
     */
    override function update(elapsed:Float)
    {
        super.update(elapsed);

        handle_spawning();

        update_notes();
        update_strums(elapsed);
    }

    /**
     * Clears every group from memory.
     */
    override function destroy()
    {
        if (onNoteHit != null) 
        { 
            onNoteHit.removeAll(); 
            onNoteHit = null; 
        }
        
        if (onSustainHit != null) 
        { 
            onSustainHit.removeAll(); 
            onSustainHit = null; 
        }
        
        if (onNoteMiss != null) 
        { 
            onNoteMiss.removeAll(); 
            onNoteMiss = null; 
        }

        strums = FlxDestroyUtil.destroy(strums);
        notes = FlxDestroyUtil.destroy(notes);
        sustains = FlxDestroyUtil.destroy(sustains);
        splashes = FlxDestroyUtil.destroy(splashes);
        covers = FlxDestroyUtil.destroy(covers);

        if (_noteList != null) { _noteList.resize(0); _noteList = null; }
        if (_heldKeys != null) { _heldKeys.resize(0); _heldKeys = null; }
        if (strumGlowTimers != null) { strumGlowTimers.resize(0); strumGlowTimers = null; }
        if (_hittableNotesCache != null) { _hittableNotesCache.resize(0); _hittableNotesCache = null; }
        
        params = null;

        _cachedSkinA = null;
        _cachedSkinB = null;

        if (_originalScales != null)
        {
            for (key in _originalScales.keys())
                _originalScales.get(key).put();

            _originalScales.clear();
            _originalScales = null;
        }

        super.destroy();
    }

    /**
     * Respawn each strum receptor in order to be updated with its key amount and skin.
     */
    function reload_strums()
    {
        var oldAnimsStrums:Array<AnimState> = captureAnimStates(strums.members);

        if (strums.length > 0)
        {
            for (arrow in strums.members)
            {
                if (arrow == null) continue;

                invalidateScale(arrow);
                arrow.destroy();
            }

            strums.clear();
        }

        var targetScale:Float = 1.0;

        if (keyCount > 4)
        {
            var defaultScale:Float = 4.0 / keyCount;
            targetScale = defaultScale + (1.0 - defaultScale) * 0.2;
        }

        targetScale *= scaleMult;

        for (i in 0...keyCount)
        {
            var strum = new Strum(i, getSkinParams());
            strum.parent = this;
            strum.ID = i;
            
            applyScale(strum);

            if (oldAnimsStrums[i] != null)
            {
                strum.play(oldAnimsStrums[i].name, true, false, oldAnimsStrums[i].frame);
                strum.visible = oldAnimsStrums[i].visible;
            }
            else
                strum.play("static", true);

            if (strum.data != null)
            {
                strum.x = (i * ((strum.data.strumWidth * 0.7) * targetScale));
                strum.y = (((strum.data.strumWidth * 0.7) - strum.height) / 2) + strum.data.position[1];
            }
            else 
            {
                strum.x = (i * (112 * 0.7 * targetScale));
                strum.y = 50; 
            }

            strums.add(strum);
            strum.sync();
        }

        var minX:Float = Math.POSITIVE_INFINITY;
        var maxX:Float = Math.NEGATIVE_INFINITY;

        for (arrow in strums.members) 
        {
            if (arrow.x < minX)
                minX = arrow.x;
            if (arrow.x + arrow.width > maxX)
                maxX = arrow.x + arrow.width;
        }

        var totalWidth:Float = maxX - minX;
        var offsetX:Float = (FlxG.width - totalWidth) / 2 + strums.x - minX;

        if (keyCount > 4 && alignStrums)
        {
            var standardWidth:Float = Constants.STRUM_WIDTH * 4;
            var pushAmount:Float = (standardWidth - totalWidth) / 2;

            if (id == 0) 
                offsetX -= pushAmount;
            else if (id == 1) 
                offsetX += pushAmount;
        }
        
        for (arrow in strums.members)
            arrow.x += offsetX + (arrow.data != null ? arrow.data.position[0] : 0);
    }

    /**
     * Rebuilds the note splash pool.
     */
    function reload_splashes()
    {
        var oldAnims:Array<AnimState> = captureAnimStates(splashes.members);
        clearGroup(splashes);

        var splashSkin:String = resolveSplashSkin();
        hasSplashes = splashSkin != null;


        if (!hasSplashes || cpu)
            return;

        var styleRef:NoteStyle = {name: splashSkin, keys: keyCount};

        for (i in 0...keyCount)
        {
            var splash = new NoteSplash(i, styleRef);
            splash.strumline = this;
            splash.parent = strums.members[i];

            applyScale(splash);

            var old = oldAnims[i];

            if (old != null)
            {
                splash.animation.play(old.name, true, false, old.frame);
                splash.visible = old.visible;
            }

            splashes.add(splash);
        }
    }

    /**
     * Rebuilds the hold cover pool.
     */
    function reload_covers()
    {
        var oldAnims:Array<AnimState> = captureAnimStates(covers.members);
        var oldActive:Array<Bool> = [for (c in covers.members) c != null && c.isActive()];

        clearGroup(covers);

        var coverSkin:String = resolveCoverSkin();
        hasCovers = coverSkin != null;

        if (!hasCovers)
            return;

        var styleRef:NoteStyle = {name: coverSkin, keys: keyCount};

        for (i in 0...keyCount)
        {
            var cover = new HoldCover(i, styleRef);
            cover.strumline = this;
            cover.parent = strums.members[i];

            applyScale(cover);

            var old = oldAnims[i];

            if (old != null)
            {
                cover.playAnimation(old.name, true, false, old.frame);
                cover.visible = old.visible;
            }

            if (i < oldActive.length && oldActive[i])
                cover.setActive(true);

            covers.add(cover);
        }
    }

    /**
     * Scales a sprite by tracking its original scale.
     */
    function applyScale(sprite:FunkinSprite, isSustain:Bool = false)
    {
        if (sprite == null || !sprite.exists) return;

        if (!_originalScales.exists(sprite))
            _originalScales.set(sprite, FlxPoint.get(sprite.scale.x, sprite.scale.y));

        var orig = _originalScales.get(sprite);

        if (isSustain)
            sprite.scale.x = orig.x * scaleMult;
        else
            sprite.scale.set(orig.x * scaleMult, orig.y * scaleMult);

        sprite.updateHitbox();
    }

    /**
     * Removes a sprite's cached scale so the next `applyScale` validates it.
     */
    inline function invalidateScale(sprite:FunkinSprite):Void
    {
        if (sprite != null && _originalScales.exists(sprite))
        {
            _originalScales.get(sprite).put();
            _originalScales.remove(sprite);
        }
    }

    /**
     * Snapshots the current animation state of every member in a group so it can be restored after the group is rebuilt.
     * @param members The group members to capture.
     * @return An index array of animation snapshots.
     */
    function captureAnimStates<T:FunkinSprite>(members:Array<T>):Array<AnimState>
    {
        var states:Array<AnimState> = [];

        for (i in 0...members.length)
        {
            var member = members[i];

            if (member != null && member.exists && member.animation != null && member.animation.curAnim != null)
                states[i] = {name: member.animation.curAnim.name, frame: member.animation.curAnim.curFrame, visible: member.visible};
        }

        return states;
    }

    /**
     * Destroys and clears every member of a note-object group, releasing any cached scale.
     * @param group The group to empty.
     */
    function clearGroup<T:FunkinSprite>(group:FlxTypedSpriteGroup<T>):Void
    {
        if (group == null || group.length == 0) return;

        for (member in group.members)
        {
            if (member == null) continue;

            invalidateScale(member);
            member.destroy();
        }

        group.clear();
    }

    /**
     * Resolves which noteskin should load the hold covers for the active style.
     * @return The skin name to load covers from.
     */
    function resolveCoverSkin():String
    {
        var effSkin:String = resolveEffectiveSkin(skin, keyCount);
        var style = NoteSkinRegistry.getStyle(effSkin);

        if (style == null || style.hasCovers == false)
            return null;

        if (skinHasCovers(effSkin))
            return effSkin;

        var fallback = (style.fallbackCovers != null && style.fallbackCovers != "") ? style.fallbackCovers : "default";

        if (fallback != effSkin && skinHasCovers(fallback))
            return fallback;

        return null;
    }

    /**
     * Resolves which noteskin should supply the note splashes for the active style.
     * @return The skin name to load splashes from.
     */
    function resolveSplashSkin():String
    {
        var effSkin:String = resolveEffectiveSkin(skin, keyCount);
        var style = NoteSkinRegistry.getStyle(effSkin);

        if (style == null || style.hasSplashes == false)
            return null;

        if (skinHasSplashes(effSkin))
            return effSkin;

        if (KeyUtil.isMultiKey(keyCount))
            return null;

        var fallback = (style.fallbackSplashes != null && style.fallbackSplashes != "") ? style.fallbackSplashes : "default";

        if (fallback != effSkin && skinHasSplashes(fallback))
            return fallback;

        return null;
    }

    /**
     * Whether the given skin actually has hold cover skins for the current key count.
     */
    inline function skinHasCovers(name:String):Bool
    {
        var data = NoteSkinRegistry.getCover(name);
        return data != null && hasSkinImages('game/notes/covers/$name', data.type);
    }

    /**
     * Whether the given skin actually has note splash skins for the current key count.
     */
    inline function skinHasSplashes(name:String):Bool
    {
        var data = NoteSkinRegistry.getSplash(name);
        return data != null && hasSkinImages('game/notes/splashes/$name', data.type, true);
    }

    /**
     * Checks whether the image assets for a splash/cover skin exist.
     * @param basePath The image folder for the skin (without extension).
     * @param type The skin's `type`.
     * @return Whether at least one required image exists.
     */
    function hasSkinImages(basePath:String, type:String, strictMultiKey:Bool = false):Bool
    {
        if (type == "SEPARATE")
        {
            for (i in 0...keyCount)
            {
                var colDir:String = Constants.COLOR_DIRECTIONS[keyCount][i];
                if (Paths.exists('images/$basePath/$colDir.png'))
                    return true;
            }

            return false;
        }

        if (strictMultiKey && KeyUtil.isMultiKey(keyCount))
            return Paths.exists('images/$basePath/skin-multikey.png');

        return Paths.exists('images/$basePath/skin.png');
    }

    /**
     * Sets up the notes by pushing the raw chart data to an array and sorting it by each note's time.
     */
    function setup_notes()
    {                
        for (data in params.data.notes)
        {
            _noteList.push(data);
        }

        _noteList.sort(function(a, b) return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time));
    }

    /**
     * Plays the intro animation for each receptor. Played during the countdown.
     */
    public function intro_animation()
    {
        inIntro = true;

        for (arrow in strums.members)
        {
            if (arrow == null) continue;

            var keyMult = 4.0 / keyCount;

            FlxTween.cancelTweensOf(arrow);
            FlxTween.cancelTweensOf(arrow.scale);

            arrow.alpha = 0;
            arrow.x += (id <= 0 ? -50 : 50) * keyMult;
            arrow.y -= 20;

            FlxTween.tween(arrow, {x: arrow.x + ((id <= 0 ? 50 : -50) * keyMult)}, 1, {ease: FlxEase.backOut, startDelay: (0.1 * keyMult) * arrow.ID, onComplete: function(t)
            {
                if (arrow.ID == strums.length - 1)
                    inIntro = false;
            }});

            FlxTween.tween(arrow, {alpha: 1, y: arrow.y + 20}, 0.7, {ease: FlxEase.quintOut, startDelay: (0.1 * (4.0 / keyCount)) * arrow.ID});
        }
    }

    /**
     * Checks if `_noteList` against the `Conductor` position to see if any new notes should be spawned.
     */
    private function handle_spawning():Void
    {
        while (_currentNoteIndex < _noteList.length)
        {
            var data = _noteList[_currentNoteIndex];

            if (data.time - Conductor.instance.songPosition >= Constants.NOTE_SPAWN_TIME)
                break;

            var note:Note = create_note(data);

            if (data.length > 0)
                note.sustain = create_sustain(data, note);

            _currentNoteIndex++;
        }
    }

    /**
     * Calculates positioning, clipping and penalties for each active note. 
     */
    private function update_notes():Void
    {
        for (note in notes.members) 
        {
            if (note == null || !note.alive) continue;

            if (note.direction >= keyCount)
            {
                note.visible = false;
                note.mustHit = false;
                
                if (note.time <= Conductor.instance.songPosition - 400)
                {
                    note.kill();
                }
                
                continue;
            }

            note.active = true;
            note.visible = true;
            note.mustHit = !cpu;

            if (note.sustain != null)
                note.sustain.mustHit = note.mustHit;

            note.distance = (-0.45 * (Conductor.instance.songPosition - note.time) * speed);
            
            if (note.parent != null)
            {
                note.y = note.parent.y + (note.parent.height - note.height) / 2 + note.distance;

                note.sync();
                applyScale(note);
            }
            else
            {
                note.y = -2000;
            }

            if (!note.mustHit)
            {
                if (note.time <= Conductor.instance.songPosition)
                {
                    note.hit = true;

                    if (note.sustain != null)
                    {
                        note.sustain.hit = true;
                        note.sustain.missed = false;
                        note.sustain.missHandled = false;

                        if (note.parent != null && speed > 0)
                            note.sustain.fullLength += (note.parent.height / 4) / (0.45 * speed);

                        note.sustain.length = Math.min(note.sustain.fullLength, (note.sustain.time + note.sustain.fullLength) - Conductor.instance.songPosition);
                    }
                }
            }

            if (note.sustain != null && note.tooLate && !note.hit)
            {
                note.sustain.missed = true;
                
                note.sustain.missHandled = true;
                note.missHandled = true;
            }

            if (!note.mustHit && note.hit && !note.enemyHit) 
            {
                onNoteHit.dispatch(note);
                note.kill();

                note.enemyHit = true;
            }

            if (note.time <= Conductor.instance.songPosition - 400)
            {
                if (!note.hit && note.mustHit)
                    onNoteMiss.dispatch(note);

                note.kill();
            }
        }

        for (sustain in sustains.members)
        {
            if (sustain == null || !sustain.exists || !sustain.alive) continue;

            sustain.mustHit = !cpu;

            if (sustain.direction >= keyCount || sustain.strum == null)
            {
                sustain.visible = false;
                sustain.mustHit = false;
                
                if (sustain.time <= Conductor.instance.songPosition - 400)
                {
                    sustain.kill();
                }
                
                continue;
            }

            if (sustain.length < sustain.fullLength)
            {
                if (!cpu && !isKeyHeld(sustain.direction) && !sustain.missed)
                {
                    sustain.missed = true;

                    if (hasCovers && covers.members[sustain.direction] != null)
                        covers.members[sustain.direction].finish();

                    if (sustain.length <= 160)
                    {
                        sustain.kill();
                        continue;
                    }
                    else
                    {
                        sustain.missed = true;

                        if (hasCovers && covers.members[sustain.direction] != null)
                            covers.members[sustain.direction].hide();

                        onNoteMiss.dispatch(sustain.note);
                        sustain.missHandled = true;
                    }
                }
            }

            var yPosition:Float = sustain.strum.y + (sustain.strum.height / 4) + (-0.45 * (Conductor.instance.songPosition - sustain.time) * speed);
            
            if (Conductor.instance.songPosition >= sustain.time + sustain.fullLength + 400)
            {
                sustain.kill();
            }
            else if (sustain.missed && (sustain.fullLength > sustain.length)) 
            {
                var yOffset:Float = SustainNote.sustainHeight(sustain.fullLength - sustain.length, speed);
                sustain.y = yPosition + (sustain.strum.height / 4) + yOffset;
            }
            else if (sustain.hit && !sustain.missed)
            {
                if (Conductor.instance.songPosition < sustain.time)
                {
                    sustain.fullLength = (sustain.time + sustain.fullLength) - Conductor.instance.songPosition;
                    sustain.time = Conductor.instance.songPosition;
                }

                sustain.length = (sustain.time + sustain.fullLength) - Conductor.instance.songPosition;

                onSustainHit.dispatch(sustain);

                if (sustain.length <= 0)
                {
                    sustain.kill();
                    continue;
                }
                
                sustain.y = sustain.strum.y + sustain.strum.height / 2;
            }
            else
            {
                sustain.y = yPosition + sustain.strum.height / 2;
            }

            sustain.sync(); 
            applyScale(sustain, true);
        }
    }

    /**
     * Manages receptor glow timers, reverting them to their 'static' animation once the hit animation finishes.
     */
    private function update_strums(elapsed:Float)
    {
        for (i in 0...keyCount)
        {
            if (strumGlowTimers[i] > 0)
            {
                strumGlowTimers[i] -= elapsed * 1000;

                if (strumGlowTimers[i] <= 0)
                {
                    strumGlowTimers[i] = 0;
                    
                    var strum = strums.members[i];
                    if (strum != null && strum.alive && strum.exists && strum.animation != null)
                    {
                        if (strum.animation.name == "confirm")
                            strum.play("static", true);
                    }
                }
            }
        }
    }

    /**
     * Fetches a note from the pool or creates a new one if the pool is empty.
     * @return Recycled note.
     */
    function recycle_note():Note
    {
        var note:Note = notes.getFirstDead();

        if (note == null)
        {
            note = new Note(0);
            notes.add(note); 
        }
        else
        {
            note.revive();
        }

        return note;
    }

    /**
     * Initializes a note with the chart data and readies it.
     * @param data The note data.
     * @return The note.
     */
    function create_note(data:ChartNote):Note
    {
        var note:Note = recycle_note();

        note.strumline = this;
        note.direction = data.direction;
        note.time = data.time;

        if (note.direction < keyCount)
        {
            note.parent = strums.members[note.direction];
            note.skin = getSkinParams();
            invalidateScale(note);
        }
        else
        {
            note.parent = null;
            note.visible = false;
        }

        return note;
    }

    /**
     * Fetches a sustain from the pool or creates a new one if the pool is empty.
     * @return Recycled sustain.
     */
    function recycle_sustain():SustainNote
    {
        var sustain:SustainNote = sustains.getFirstDead();

        if (sustain == null)
        {
            sustain = new SustainNote(this);
            sustains.add(sustain); 
        }
        else
        {
            sustain.revive();
        }

        return sustain;
    }


    /**
     * Initializes a sustain with the chart data and readies it.
     * @param data The note data.
     * @return The sustain.
     */
    function create_sustain(data:ChartNote, note:Note):SustainNote
    {
        var sustain:SustainNote = recycle_sustain();

        sustain.note = note;
        sustain.strum = note.parent;
        sustain.strumline = this;

        sustain.time = data.time;
        sustain.direction = data.direction;

        sustain.skin = getSkinParams();
        invalidateScale(sustain);
        sustain.length = data.length;

        sustain.hit = false;
        sustain.missed = false;
        sustain.missHandled = false;

        sustain.redraw();
        sustain.updateAlpha();

        sustain.y = -9999;
        sustain.scrollFactor.set();
        sustain.visible = true;

        applyScale(sustain, true);

        return sustain;
    }

    /**
     * Sorts notes based on their strum time'. 
     * Different because this takes into account the note's priority level.
     * @param a The first note you want to compare.
     * @param b The second note you want to compare.
     * @return The comparing value used when sorting.
     */
    public function sortHitNotes(a:Note, b:Note):Int
    {
        return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
    }

    /**
     * Returns each note that's in the hit window.
     * @param key The key direction to check notes for.
     * @return A list of notes that satisfy the hittable condition.
     */
    public function filterHittableNotes(key:Int):Array<Note>
    {
        _hittableNotesCache.resize(0);

        for (note in notes.members)
        {
            if (note != null && note.alive && note.canBeHit && !note.hit && note.direction == key)
                _hittableNotesCache.push(note);
        }

        return _hittableNotesCache;
    }

    /**
     * Whether a sustain on the given direction is currently being held (glowing).
     * @param direction The note direction to check.
     */
    public function hasActiveSustain(direction:Int):Bool
    {
        for (sustain in sustains.members)
        {
            if (sustain != null && sustain.alive && sustain.direction == direction && sustain.glow && sustain.length > 0)
                return true;
        }

        return false;
    }

    /**
     * Called when the specific note direction key is pressed.
     * @param direction The note direction to press.
     */
    public function pressKey(direction:Int)
    {
        _heldKeys[direction] = true;
    }

    /**
     * Called when the specific note direction key is pressed.
     * @param direction The note direction to release.
     */
    public function releaseKey(direction:Int)
    {
        _heldKeys[direction] = false;
    }

    /**
     * Checks whether the given note direction key is being pressed.
     * @param direction The direction to check.
     * @return Whether the direction key is pressed.
     */
    function isKeyHeld(direction:Int):Bool
    {
        return _heldKeys[direction] == true;
    }
}