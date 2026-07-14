package game.handlers;

import flixel.FlxBasic;

import flixel.util.FlxStringUtil;
import openfl.media.Sound;
import backend.assets.Cacher;
import backend.assets.FunkinSound;

/**
 * A class used to handle song playback and synchronization.
 */
class Song extends FlxBasic
{
    /**
     * The name of the song.
     */
    public var name:String;

    /**
     * The variation file suffix.
     */
    public var variationSuffix:String = "";

    /**
     * The song's instrumental track.
     */
    public var inst:FunkinSound;

    /**
     * The song's vocal tracks.
     */
    public var voices:Map<String, FunkinSound> = [];

    /**
     * Internal sound group.
     */
    private var _soundList:Array<FunkinSound> = [];

    /**
     * Streaming sounds opened by this song instance.
     */
    private var _ownedStreams:Array<Sound> = [];

    /**
     * Tracks which sounds were playing when the window lost focus, so only those get resumed when focus returns.
     */
    private var _resumeOnFocus:Array<FunkinSound> = [];

    /**
     * Formatted string to show the current time elapsed in the song. (XX:XX)
     */
    public var timeElapsedString(get, null):String;

    function get_timeElapsedString():String
        return FlxStringUtil.formatTime(Std.int((inst != null ? inst.time : 0.0) / 1000));

    /**
     * Formatted string to show the time left in the song. (X:XX)
     */
    public var timeLeftString(get, null):String;

    function get_timeLeftString():String
        return FlxStringUtil.formatTime(Std.int((inst != null ? inst.length : 0.0) / 1000));

    /**
     * Loads the song files and prepares them for playback.
     * @param name The name of the song.
     */
    public function new(name:String, ?variationSuffix:String)
    {
        super();
        this.name = name;
        this.variationSuffix = variationSuffix ?? "";

        Conductor.instance.onStepHit.add(stepHit);

        FlxG.signals.focusLost.add(onFocusLost);
        FlxG.signals.focusGained.add(onFocusGained);

        inst = loadTrack('Inst${this.variationSuffix}');

        if (inst == null)
        {
            inst = new FunkinSound();
            inst.volume = 0;
        }

        _soundList.push(inst);
    }

    /**
     * Loads a track from the preloaded cache when available, falling back to disk streaming. Returns null when the file doesn't exist at all.
     * @param fileName The track's file name inside the song folder, without extension.
     */
    private function loadTrack(fileName:String):FunkinSound
    {
        var cacheKey = Paths.songTrackKey(name, fileName);
        var cached = Paths.findCachedSound(cacheKey);

        if (cached != null)
        {
            var track = new FunkinSound();
            track.loadEmbedded(cached);
            return track;
        }

        if (Paths.exists('songs/$name/$fileName.ogg'))
        {
            var track = new FunkinSound();
            track.loadStream(Paths.getPath(cacheKey));
            registerStream(track);
            return track;
        }

        return null;
    }

    /**
     * Registers the stream the sound just opened so this instance can open/close it.
     */
    private function registerStream(track:FunkinSound):Void
    {
        @:privateAccess
        if (track != null && track._sound != null)
        {
            _ownedStreams.push(track._sound);
            Cacher.instance.registerStream(track._sound);
        }
    }

    /**
     * Initializes a vocal track and adds it to the map.
     * @param character The name of the character.
     */
    public function initVocalTrack(character:String):Void
    {
        var track:FunkinSound = loadTrack('Voices-$character${variationSuffix}');

        if (track == null)
        {
            if (voices.exists('globalVocalTrack'))
                return;

            track = loadTrack('Voices${variationSuffix}');

            if (track != null)
                voices.set('globalVocalTrack', track);
            else
            {
                trace('Vocals missing for character ' + character + '. Creating empty track...', "WARNING");
                track = new FunkinSound();
                track.volume = 0;
            }
        }

        voices.set(character, track);
        _soundList.push(track);
    }

    /**
     * Internal variable tracking whether the song has started.
     */
    private var _started:Bool = false;

    /**
     * Internal variable making sure the end-of-song callback (onComplete) only fires once.
     */
    private var _completed:Bool = false;

    public function play()
    {
        _started = true;
        _completed = false;

        for (i in _soundList) i?.play();
    }

    public function stop() for (i in _soundList) i?.stop();

    /**
     * Fires the instrumental's `onComplete` callback once the song's current time passes its length.
     */
    private function checkCompletion():Void
    {
        if (!_started || _completed || inst == null || inst.length <= 0)
            return;

        if (Conductor.instance.songPosition < inst.length)
            return;

        _completed = true;

        var callback:Void->Void = inst.onComplete;

        stop();

        if (callback != null)
            callback();
    }

    /**
     * Pauses every playing track when the window loses focus.
     */
    function onFocusLost():Void
    {
        for (track in _soundList)
        {
            if (track != null && track.playing)
            {
                _resumeOnFocus.push(track);
                track.pause();
            }
        }
    }

    /**
     * Resumes the tracks that were playing before focus was lost. 
     */
    function onFocusGained():Void
    {
        for (track in _resumeOnFocus)
            track?.resume();

        _resumeOnFocus.resize(0);
    }

    /**
     * Keeps every track's internal state (time, amplitude, transforms) synced.
     */
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        for (track in _soundList)
        {
            if (track != null && track.isPlaying)
                track.update(elapsed);
        }

        checkCompletion();
    }

    /**
     * Stops playback and destroys every track.
     */
    override public function destroy()
    {
        FlxG.signals.focusLost.remove(onFocusLost);
        FlxG.signals.focusGained.remove(onFocusGained);

        _resumeOnFocus.resize(0);

        for (track in _soundList)
            track?.stop();

        for (snd in _ownedStreams)
            Cacher.instance.closeStream(snd);

        _ownedStreams.resize(0);

        for (track in _soundList)
            track?.destroy();

        _soundList.resize(0);
        voices.clear();
        inst = null;

        super.destroy();
    }

    /**
     * Checks if a vocal track is not synced to the instrumental in order to sync it again.
     * @param step The current step.
     */
    function stepHit(step:Float):Void
    {
        if (step % 4 != 0) return;

        if (inst == null || !inst.playing)
            return;

        if (inst.length > 0 && Conductor.instance.songPosition >= inst.length)
            return;

        for (voice in voices)
        {
            if (voice != null && voice.playing && Math.abs(voice.time - inst.time) > Constants.RESYNC_THRESHOLD)
                voice.time = inst.time;
        }
    }

    /**
     * Utilized for muting or unmuting the player vocal track on note miss / hit.
     */
    public function changePlayerVolume(volume:Float = 1.0, character:String):Void
    {
        var index:String = "";

        if (voices.exists(character))
            index = character;
        else if (voices.exists("globalVocalTrack"))
            index = "globalVocalTrack";

        if (index == "")
            return;

        voices[index].volume = volume;
    }
}
