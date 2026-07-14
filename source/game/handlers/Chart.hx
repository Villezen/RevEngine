package game.handlers;

import backend.registries.song.ChartRegistry;

/**
 * A handler class that loads and parses chart JSON files.
 */
class Chart
{
    /**
     * The raw, validated chart data from the registry.
     */
    public var data(default, null):ChartData;

    /**
     * The difficulty this chart was loaded with.
     */
    public var difficulty(default, null):String;

    /**
     * The variation file suffix this chart was loaded with (e.g. "-pico"), "" for the default.
     */
    public var variation(default, null):String;

    /**
     * The processed strumline data.
     */
    public var strumlines:Array<ChartStrumline>;

    /**
     * Loads a chart file from the assets and parses it.
     * @param song The name of the song.
     * @param difficulty The difficulty to load, defaults to `Constants.DEFAULT_DIFFICULTY`.
     * @param variation The variation file suffix (e.g. "-pico"), "" for the default variation.
     */
    public function new(song:String, ?difficulty:String, ?variation:String)
    {
        this.difficulty = difficulty ?? Constants.DEFAULT_DIFFICULTY;
        this.variation = variation ?? "";

        data = ChartRegistry.get(song, this.difficulty, this.variation);
        strumlines = data.strumlines;
    }
}
