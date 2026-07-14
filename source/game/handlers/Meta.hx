package game.handlers;

import backend.registries.song.MetaRegistry;

/**
 * A handler class that manages song metadata.
 */
class Meta
{
    /**
     * Internal storage for the raw metadata object.
     */
    private var data:MetaData;

    /**
     * Publicly accessible display name.
     */
    public var name:String;

    /**
     * Publicly accessible icon name.
     */
    public var icon:String;

    /**
     * Publicly accessible BPM value.
     */
    public var bpm:Float;

    /**
     * Publicly accessible stage name.
     */
    public var stage:String;

    /**
     * Publicly accessible album data.
     */
    public var album:MetaAlbumData;

    /**
     * Publicly accessible freeplay data.
     */
    public var freeplay:MetaFreeplayData;

    /**
     * Publicly accessible song composers.
     */
    public var composers:Array<String>;

    /**
     * Publicly accessible song artists.
     */
    public var artists:Array<String>;

    /**
     * Publicly accessible song charters.
     */
    public var charters:Array<String>;

    /**
     * Publicly accessible countdown data.
     */
    public var countdown:CountdownSkinData;

    /**
     * Publicly accessible ratings data.
     */
    public var ratings:RatingSkinData;

    /**
     * Loads metadata for a specific song.
     * @param song The name of the song.
     * @param variation The variation file suffix.
     */
    public function new(song:String, ?variation:String)
    {
        data = MetaRegistry.get(song, variation);

        name = data.name;
        icon = data.icon;
        bpm = data.bpm;

        stage = data.stage;

        album = data.album;
        freeplay = data.freeplay;

        composers = data.composers;
        artists = data.artists;
        charters = data.charters;

        countdown = data.countdown;
        ratings = data.ratings;
    }
}