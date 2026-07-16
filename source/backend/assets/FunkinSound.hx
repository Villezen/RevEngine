package backend.assets;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.util.FlxSignal.FlxTypedSignal;

import lime.media.AudioSource;

import openfl.events.Event;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundMixer;
import openfl.net.URLRequest;

import lime.math.Vector4;

/**
 * An FlxSound which adds additional functionality, heavily based off how V-Slice does it.
 */
class FunkinSound extends FlxSound
{
    static final MAX_VOLUME:Float = 1.0;

    /**
     * How many destroyed sounds are kept around for recycling. Anything above this count gets fully released so the garbage collector can reclaim it.
     */
    static final MAX_DEAD_POOL_SIZE:Int = 12;

    /**
     * An FlxSignal which is dispatched when the game's volume changes.
     */
    public static var onVolumeChanged(get, never):FlxTypedSignal<Float->Void>;

    static var _onVolumeChanged:FlxTypedSignal<Float->Void> = null;

    static function get_onVolumeChanged():FlxTypedSignal<Float->Void>
    {
        if (_onVolumeChanged == null)
        {
            _onVolumeChanged = new FlxTypedSignal<Float->Void>();

            FlxG.sound.onVolumeChange.add(function(volume:Float)
            {
                _onVolumeChanged.dispatch(volume);
            });
        }
        return _onVolumeChanged;
    }

    /**
     * Loading a sound will override a dead instance from here rather than creating a new one, if possible!
     */
    static var pool(default, null):FlxTypedGroup<FunkinSound> = new FlxTypedGroup<FunkinSound>();

    /**
     * Mutes this sound without touching its volume, so unmuting restores the previous volume.
     */
    public var muted(default, set):Bool = false;

    function set_muted(value:Bool):Bool
    {
        if (value == muted)
            return value;

        muted = value;
        updateTransform();

        return value;
    }

    override function calcTransformVolume():Float
    {
        return muted ? 0.0 : super.calcTransformVolume();
    }

    var _appliedVolume:Float = -1.0;
    var _appliedPan:Float = 2.0;

    override function updateTransform():Void
    {
        _transform.volume = calcTransformVolume();

        if (_channel != null && (_transform.volume != _appliedVolume || _transform.pan != _appliedPan))
        {
            _channel.soundTransform = _transform;
            _appliedVolume = _transform.volume;
            _appliedPan = _transform.pan;
        }
    }

    override function set_volume(value:Float):Float
    {
        _volume = FlxMath.bound(value, 0.0, MAX_VOLUME);
        updateTransform();
        return _volume;
    }

    public var paused(get, never):Bool;

    function get_paused():Bool
    {
        return this._paused;
    }

    /**
     * Whether this sound is playing, including sounds waiting at a negative timestamp.
     */
    public var isPlaying(get, never):Bool;

    function get_isPlaying():Bool
    {
        return this.playing || this._shouldPlay;
    }

    /**
     * If true, the game will forcefully add this sound's channel to the list of playing sounds, bypassing OpenFL's active channel limit.
     */
    public var important:Bool = false;

    /**
     * Are we in a state where the sound should play but time is negative?
     */
    var _shouldPlay:Bool = false;

    /**
     * Whether this sound opened its own stream.
     */
    var _ownsStream:Bool = false;

    /**
     * For debug purposes.
     */
    var _label:String = "unknown";

    public function new()
    {
        super();
    }

    override public function update(elapsed:Float):Void
    {
        if (!playing && !_shouldPlay)
            return;

        if (_length <= 0 && _sound != null && _sound.length > 0)
            _length = _sound.length;

        if (_time < 0)
        {
            _time += elapsed * 1000.0;

            if (_time >= 0)
            {
                super.play();
                _shouldPlay = false;
            }
        }
        else
        {
            super.update(elapsed);

            @:privateAccess
            if (important && _channel != null && !SoundMixer.__soundChannels.contains(_channel))
                SoundMixer.__soundChannels.push(_channel);
        }
    }

    public function togglePlayback():FunkinSound
    {
        if (playing)
            pause();
        else
            resume();

        return this;
    }

    override public function play(forceRestart:Bool = false, startTime:Float = 0.0, ?endTime:Float):FunkinSound
    {
        if (!exists)
            return this;

        if (forceRestart)
        {
            cleanup(false, true);
            _shouldPlay = false;
        }
        else if (isPlaying)
        {
            return this;
        }

        if (startTime < 0)
        {
            this.active = true;
            this._shouldPlay = true;
            this._time = startTime;
            this.endTime = endTime;

            return this;
        }

        if (_paused)
            resume();
        else
            startSound(startTime);

        this.endTime = endTime;
        return this;
    }

    override public function pause():FunkinSound
    {
        if (_shouldPlay)
        {
            _shouldPlay = false;
            _paused = true;
            active = false;
        }
        else
        {
            super.pause();
        }

        return this;
    }

    override public function resume():FunkinSound
    {
        if (this._time < 0)
        {
            _shouldPlay = true;
            _paused = false;
            active = true;
        }
        else
        {
            super.resume();
        }

        return this;
    }

    /**
     * Creates a copy of this sound that can play independently of the original.
     */
    public function clone():FunkinSound
    {
        var sound:FunkinSound = new FunkinSound();

        @:privateAccess
        if (this._sound != null)
        {
            if (this._sound.__buffer != null)
                sound._sound = Sound.fromAudioBuffer(this._sound.__buffer);
            else if (this._sound.url != null)
                sound._sound = new Sound(new URLRequest(this._sound.url));
        }

        sound.init(this.looped, this.autoDestroy, this.onComplete);
        sound._label = this._label;

        return sound;
    }

    /**
     * Creates a new instance and loads it as the current music track.
     *
     * @param key The name of the music track, as passed to the paths function.
     * @param params A set of additional optional parameters.
     * @return Whether the music was started. Returns `false` if music was already playing or could not be started.
     */
    public static function playMusic(key:String, ?params:FunkinSoundPlayMusicParams):Bool
    {
        if (params == null) params = {};

        if (!(params.overrideExisting ?? false) && (FlxG.sound.music?.exists ?? false) && FlxG.sound.music.playing)
            return false;

        var asset:Sound = switch (params.type ?? SoundType.AUDIO)
        {
            case MUSIC: Paths.music(key);
            case SOUND: Paths.sound(key);
            case AUDIO: Paths.audio(key, "audio", "ogg", false, false, true);
        }

        if (asset == null)
        {
            trace('Failed to find music track: $key', "WARNING");
            return false;
        }

        var label:String = asset.url != null ? asset.url : key;

        if (!(params.restartTrack ?? false) && (FlxG.sound.music?.playing ?? false))
        {
            if (Std.isOfType(FlxG.sound.music, FunkinSound))
            {
                var existingSound:FunkinSound = cast FlxG.sound.music;

                if (existingSound._label == label)
                    return false;
            }
        }

        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.fadeTween?.cancel();
            FlxG.sound.music.stop();
            FlxG.sound.music.kill();
        }

        var music = FunkinSound.load(asset, params.startingVolume ?? 1.0, params.loop ?? true, false, true, params.persist ?? false, params.onComplete, params.onLoad);

        if (music == null)
            return false;

        music._label = label;
        setMusic(music);

        return true;
    }

    /**
     * Replaces the current Flixel music object with the given sound.
     * @param newMusic The new music to be set as the current music.
     */
    public static function setMusic(newMusic:FunkinSound):Void
    {
        FlxG.sound.music = newMusic;
        FlxG.sound.list.remove(FlxG.sound.music);
    }

    /**
     * Creates a new sound object synchronously.
     *
     * @param embeddedSound The sound resource to play. Can be a `Sound` object, an asset ID string, or a `Class<Sound>`.
     * @param volume How loud to play it (0 to 1).
     * @param looped Whether to loop this sound.
     * @param autoDestroy Whether to destroy this sound when it finishes playing. Leave false if you're planning to reuse this sound.
     * @param autoPlay Whether to play the sound immediately or wait for a `play()` call.
     * @param persist Whether to keep this sound between states, or destroy it.
     * @param onComplete Called when the sound finished playing.
     * @param onLoad Called when the sound finished loading. Called immediately for successfully loaded embedded sounds.
     * @param important If `true`, the sound channel will forcefully be added onto the channel array, even if full. Use sparingly!
     * @return A sound object, or `null` if the sound could not be loaded.
     */
    public static function load(embeddedSound:FlxSoundAsset, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false, persist:Bool = false, ?onComplete:Void->Void, ?onLoad:Void->Void, important:Bool = false):Null<FunkinSound>
    {
        @:privateAccess
        if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS && !important)
        {
            trace('FunkinSound could not play sound, channels exhausted! Found ${@:privateAccess SoundMixer.__soundChannels.length} active sound channels.',
                "WARNING");
            return null;
        }

        if (embeddedSound == null)
            return null;

        var sound:FunkinSound = pool.recycle(construct);
        sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);

        if ((embeddedSound is String))
            sound._label = embeddedSound;
        else if ((embeddedSound is Sound) && cast(embeddedSound, Sound).url != null)
            sound._label = cast(embeddedSound, Sound).url;
        else
            sound._label = 'unknown';

        if (autoPlay)
            sound.play();

        sound.volume = volume;
        sound.persist = persist;
        sound.important = important;

        FlxG.sound.defaultSoundGroup.add(sound);
        FlxG.sound.list.add(sound);

        if (onLoad != null && sound._sound != null)
            onLoad();

        return sound;
    }

    /**
     * Creates a new sound which streams its audio from a file on disk, decoding it on the fly instead of loading the entire sound into memory.
     *
     * @param path The path to the sound file on disk.
     * @param volume How loud to play it (0 to 1).
     * @param looped Whether to loop this sound.
     * @param autoDestroy Whether to destroy this sound when it finishes playing. Leave false if you're planning to reuse this sound.
     * @param autoPlay Whether to play the sound immediately or wait for a `play()` call.
     * @param persist Whether to keep this sound between states, or destroy it.
     * @param onComplete Called when the sound finished playing.
     * @param onLoad Called when the sound finished opening its stream.
     * @param important If `true`, the sound channel will forcefully be added onto the channel array, even if full. Use sparingly!
     * @return A sound object, or `null` if the sound could not be loaded.
     */
    public static function loadStreamed(path:String, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false, persist:Bool = false, ?onComplete:Void->Void, ?onLoad:Void->Void, important:Bool = false):Null<FunkinSound>
    {
        @:privateAccess
        if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS && !important)
        {
            trace('Sound could not be played, channels exhausted! Found ${@:privateAccess SoundMixer.__soundChannels.length} active sound channels.', "WARNING");
            return null;
        }

        if (path == null || path == "")
            return null;

        var sound:FunkinSound = pool.recycle(construct);

        sound.loadStream(path, looped, autoDestroy, onComplete, onLoad);
        sound._label = path;
        sound._ownsStream = true;

        if (autoPlay)
            sound.play();

        sound.volume = volume;
        sound.persist = persist;
        sound.important = important;

        FlxG.sound.defaultSoundGroup.add(sound);
        FlxG.sound.list.add(sound);

        return sound;
    }

    /**
     * Play a sound effect once, then destroy it.
     * @param asset The sound resource to play. Can be a `Sound` object or an asset ID string.
     * @param volume How loud to play it (0 to 1).
     * @return A sound object, or `null` if the sound could not be loaded.
     */
    public static function playOnce(asset:FlxSoundAsset, volume:Float = 1.0, ?onComplete:Void->Void, ?onLoad:Void->Void, important:Bool = false):Null<FunkinSound>
    {
        return FunkinSound.load(asset, volume, false, true, true, false, onComplete, onLoad, important);
    }

    /**
     * Stop all sounds in the pool and allow them to be recycled.
     * @param musicToo Whether to stop the current music track as well, even if it is persistent.
     * @param persistToo Whether to stop sounds marked as persistent as well.
     */
    public static function stopAllAudio(musicToo:Bool = false, persistToo:Bool = false):Void
    {
        for (sound in pool)
        {
            if (sound == null)
                continue;

            if (sound == FlxG.sound.music)
            {
                if (!musicToo)
                    continue;

                FlxG.sound.music.stop();
                FlxG.sound.music = null;
            }
            else if (!persistToo && sound.persist)
                continue;

            sound.destroy();
        }
    }

    static function construct():FunkinSound
    {
        var sound:FunkinSound = new FunkinSound();

        pool.add(sound);
        FlxG.sound.list.add(sound);

        return sound;
    }

    override public function destroy():Void
    {
        var stream:Sound = _ownsStream ? _sound : null;
        _ownsStream = false;

        super.destroy();

        if (stream != null)
        {
            try stream.close() catch (e:Dynamic) {}
        }

        if (fadeTween != null)
        {
            fadeTween.cancel();
            fadeTween = null;
        }

        FlxTween.cancelTweensOf(this);

        this._label = 'unknown';
        this._shouldPlay = false;

        prunePool(this);
    }

    /**
     * Keeps at most `MAX_DEAD_POOL_SIZE` dead sounds around for recycling. Everything beyond that is dropped from the pool and the sound list so the garbage collector can reclaim it.
     * @param exclude A sound to skip, so a sound being recycled isn't pruned mid-recycle.
     */
    static function prunePool(?exclude:FunkinSound):Void
    {
        var dead:Int = 0;
        var i:Int = pool.members.length;

        while (--i >= 0)
        {
            var sound = pool.members[i];

            if (sound == null || sound == exclude || sound.exists)
                continue;

            dead++;

            if (dead > MAX_DEAD_POOL_SIZE)
            {
                pool.remove(sound, true);
                FlxG.sound.list.remove(sound, true);
            }
        }
    }

    @:access(openfl.media.Sound)
    @:access(openfl.media.SoundChannel)
    @:access(openfl.media.SoundMixer)
    override function startSound(startTime:Float):Void
    {
        if (!important || _sound == null || _sound.__buffer == null || _sound.__urlLoading)
        {
            super.startSound(startTime);
            return;
        }

        _time = startTime;
        _paused = false;

        var pan:Float = FlxMath.bound(SoundMixer.__soundTransform.pan + _transform.pan, -1, 1);
        var volume:Float = FlxMath.bound(SoundMixer.__soundTransform.volume * _transform.volume, 0, MAX_VOLUME);

        var audioSource:AudioSource = new AudioSource(_sound.__buffer);
        audioSource.offset = Std.int(startTime);
        audioSource.gain = volume;

        var position:lime.math.Vector4 = audioSource.position;
        position.x = pan;
        position.z = -1 * Math.sqrt(1 - Math.pow(pan, 2));
        audioSource.position = position;

        _channel = new SoundChannel(_sound, audioSource, _transform);
        _channel.addEventListener(Event.SOUND_COMPLETE, stopped);

        #if FLX_PITCH
        pitch = _pitch;
        #end
        active = true;
    }

    override public function toString():String
    {
        return 'FunkinSound(${this._label})';
    }
}

/**
 * Additional parameters for `FunkinSound.playMusic()`
 */
typedef FunkinSoundPlayMusicParams =
{
    /**
     * The volume you want the music to start at.
     * @default `1.0`
     */
    var ?startingVolume:Float;

    /**
     * Whether to override music if a different track is already playing.
     * @default `false`
     */
    var ?overrideExisting:Bool;

    /**
     * Whether to restart the track if the same track is already playing.
     * @default `false`
     */
    var ?restartTrack:Bool;

    /**
     * Whether the music should loop or play once.
     * @default `true`
     */
    var ?loop:Bool;

    /**
     * Which Paths function to use to load the track.
     * @default `MUSIC`
     */
    var ?type:SoundType;

    /**
     * Whether the sound should be kept between state switches.
     * @default `false`
     */
    var ?persist:Bool;

    var ?onComplete:Void->Void;
    var ?onLoad:Void->Void;
}

/**
 * Which `Paths` function `FunkinSound.playMusic()` uses to resolve a track.
 */
enum SoundType
{
    MUSIC;
    SOUND;
    AUDIO;
}
