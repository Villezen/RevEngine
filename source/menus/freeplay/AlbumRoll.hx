package menus.freeplay;

import flixel.group.FlxSpriteGroup;

import backend.registries.song.AlbumRegistry;
import backend.registries.song.AlbumRegistry.AlbumData;
import backend.registries.song.AlbumRegistry.AlbumObjectData;

class AlbumRoll extends FlxSpriteGroup
{
    static inline final ART_X:Float = 658;
    static inline final ART_Y:Float = 370;
    static inline final TITLE_X:Float = 355;
    static inline final TITLE_Y:Float = 500;
    static inline final STARS_OFFSET_X:Float = 318.49;
    static inline final STARS_OFFSET_Y:Float = -142.49;

    public var albumId(default, set):String = null;

    var albumArt:FunkinSprite;
    var albumTitle:FunkinSprite;

    var difficultyStars:DifficultyStars;

    var albumData:AlbumData = null;

    var titleTimer:FlxTimer = null;

    var starsRevealed:Bool = false;

    public function new()
    {
        super();

        albumArt = new FunkinSprite(FlxG.width - ART_X, ART_Y);
        albumArt.visible = false;
        add(albumArt);

        difficultyStars = new DifficultyStars((FlxG.width - ART_X) + STARS_OFFSET_X, ART_Y + STARS_OFFSET_Y);
        difficultyStars.visible = false;
        add(difficultyStars);

        albumTitle = new FunkinSprite(FlxG.width - TITLE_X, TITLE_Y);
        albumTitle.visible = false;
        add(albumTitle);
    }

    inline function setAlbumVisible(value:Bool):Void
    {
        albumArt.visible = value;
        albumTitle.visible = value && albumTitle.frames != null;

        refreshStars();
    }

    function refreshStars():Void
    {
        difficultyStars.visible = starsRevealed && albumData != null;
        difficultyStars.flameCheck();
    }

    function set_albumId(value:String):String
    {
        if (albumId != value || value == null)
        {
            albumId = value;
            updateAlbum();
        }

        return value;
    }

    function updateAlbum():Void
    {
        if (albumId == null || albumId == "" || albumId == "unknown")
        {
            albumData = null;
            setAlbumVisible(false);
            return;
        }

        albumData = AlbumRegistry.get(albumId);

        if (albumData == null || albumData.sprites == null)
        {
            albumData = null;
            setAlbumVisible(false);
            return;
        }

        applyObject(albumArt, albumData.sprites.art, FlxG.width - ART_X, ART_Y);
        applyObject(albumTitle, albumData.sprites.text, FlxG.width - TITLE_X, TITLE_Y);

        difficultyStars.x = albumArt.x + STARS_OFFSET_X;
        difficultyStars.y = albumArt.y + STARS_OFFSET_Y;

        albumArt.playAnim("idle");
        albumTitle.playAnim("idle");

        setAlbumVisible(true);
    }

    function applyObject(spr:FunkinSprite, data:AlbumObjectData, baseX:Float, baseY:Float):Void
    {
        if (data == null || data.path == null || data.path == "") return;

        spr.loadSprite(data.path);

        spr.x = baseX + data.position[0];
        spr.y = baseY + data.position[1];
        spr.scale.set(data.scale[0], data.scale[1]);
        spr.alpha = data.alpha;
        spr.angle = data.angle;

        if (data.animations != null)
        {
            for (anim in data.animations)
            {
                if (anim == null) continue;

                spr.addAnim(anim.name, {
                    prefix: anim.prefix,
                    indices: anim.indices,
                    offsets: anim.offsets,
                    looped: anim.looped,
                    fps: anim.fps
                });
            }
        }
    }

    public function playIntro():Void
    {
        starsRevealed = false;
        refreshStars();

        if (titleTimer != null) titleTimer.cancel();
        var introAlbum:String = albumId;

        titleTimer = FlxTimer.wait(0.75, function()
        {
            showStars();

            if (albumData == null || albumId != introAlbum) return;

            albumTitle.visible = albumTitle.frames != null;
            playTitleSwitch();
        });

        albumTitle.visible = false;

        if (albumData == null)
        {
            albumArt.visible = false;
            return;
        }

        albumArt.visible = true;
        playArtAnim("intro");
    }

    public function setDifficultyStars(?difficulty:Int):Void
    {
        if (difficulty == null) return;

        difficultyStars.difficulty = difficulty;
    }

    public function showStars():Void
    {
        starsRevealed = true;
        refreshStars();
    }

    public function skipIntro():Void
    {
        if (albumData == null)
        {
            setAlbumVisible(false);
            return;
        }

        setAlbumVisible(true);

        playArtAnim("switch");
        playTitleSwitch();
    }

    function playArtAnim(name:String):Void
    {
        albumArt.playAnim(name, {
            force: true,
            onComplete: function() albumArt.playAnim("idle")
        });
    }

    function playTitleSwitch():Void
    {
        albumTitle.playAnim("switch", {
            force: true,
            onComplete: function() albumTitle.playAnim("idle")
        });
    }

    override function destroy():Void
    {
        if (titleTimer != null)
        {
            titleTimer.cancel();
            titleTimer = null;
        }

        super.destroy();
    }
}
