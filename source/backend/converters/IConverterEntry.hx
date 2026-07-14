package backend.converters;

import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.EventRegistry.EventData;

/**
 * Interface for the chart format converter.
 */
interface IConverterEntry
{
    /**
     * The song the converter is currently working on.
     */
    public var song:String;

    /**
     * The difficulty the converter is currently targeting.
     */
    public var difficulty:String;

    /**
     * Whether this converter recognizes the parsed JSON data.
     */
    public function detect(data:Dynamic):Bool;

    /**
     * Every difficulty contained in the parsed data.
     */
    public function listDifficulties(data:Dynamic):Array<String>;

    /**
     * Converts the chart data into the engine's chart format.
     */
    public function convertChart(data:Dynamic):ChartData;

    /**
     * Extracts the event data out of the chart data.
     */
    public function convertEvents(data:Dynamic):EventData;

    /**
     * Converts the chart data back into its original format.
     */
    public function revertChart(data:ChartData, ?eventData:EventData):Dynamic;

    /**
     * Converts event data back into its original format.
     */
    public function revertEvents(data:EventData):Dynamic;

    /**
     * Serializes data into a JSON string.
     */
    public function write(data:Dynamic):String;
}
