package backend.converters;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import backend.assets.Paths;

import backend.registries.song.ChartRegistry.ChartData;
import backend.registries.song.ChartRegistry.ChartStrumline;
import backend.registries.song.ChartRegistry.ChartNote;

import backend.registries.song.EventRegistry.EventData;
import backend.registries.song.EventRegistry.EventEntry;

import backend.converters.type.*;

/**
 * Entry point of the chart conversion pipeline.
 */
class Converter
{
    /**
     * Every registered converter, checked in order during detection.
     */
    public static var converters:Array<IConverterEntry> =
    [
        LegacyConverter.instance,
        VSliceConverter.instance
    ];

    /**
     * Returns the first converter that recognizes the parsed JSON data.
     */
    public static function detect(data:Dynamic):IConverterEntry
    {
        if (data == null) return null;

        for (converter in converters)
        {
            if (converter != null && converter.detect(data))
                return converter;
        }

        return null;
    }

    /**
     * Converts parsed different chart formats into native ones.
     */
    public static function runChart(song:String, data:Dynamic, ?difficulty:String):ChartData
    {
        var converter = detect(data);

        if (converter != null)
        {
            converter.song = song;
            converter.difficulty = difficulty;
            return converter.convertChart(data);
        }

        return cast data;
    }

    /**
     * onverts parsed different event formats into native ones.
     */
    public static function runEvents(song:String, data:Dynamic):EventData
    {
        var converter = detect(data);

        if (converter != null)
        {
            converter.song = song;
            converter.difficulty = null;
            return converter.convertEvents(data);
        }

        return cast data;
    }

    /**
     * Serializes chart data into the engine's chart format.
     */
    public static function writeChart(name:String, data:ChartData):String
    {
        var strumlines:Array<ChartStrumline> = [];

        if (data != null && data.strumlines != null)
        {
            for (strumline in data.strumlines)
                if (strumline != null) strumlines.push(strumline);
        }

        var buf:StringBuf = new StringBuf();

        buf.add("{");
        buf.add("\n\t\"strumlines\":\n\t[");

        for (s in 0...strumlines.length)
        {
            var strumLine:ChartStrumline = strumlines[s];

            var notes:Array<ChartNote> = [];

            if (strumLine.notes != null)
            {
                for (note in strumLine.notes)
                    if (note != null) notes.push(note);
            }

            var position:Array<Int> = (strumLine.position != null && strumLine.position.length >= 2) ? strumLine.position : [0, 0];

            buf.add("\n\t\t{");
            buf.add("\n\t\t\t\"id\": " + (strumLine.id ?? 0) + ",");
            buf.add("\n\t\t\t\"character\": " + Json.stringify(strumLine.character ?? "bf") + ",\n");

            buf.add("\n\t\t\t\"skin\": " + Json.stringify(strumLine.skin ?? "default") + ",");
            buf.add("\n\t\t\t\"position\": " + Json.stringify(position) + ",");
            buf.add("\n\t\t\t\"scale\": " + (strumLine.scale ?? 1.0) + ",");
            buf.add("\n\t\t\t\"visible\": " + (strumLine.visible ?? true) + ",\n");

            buf.add("\n\t\t\t\"speed\": " + (strumLine.speed ?? 1.0) + ",");
            buf.add("\n\t\t\t\"keys\": " + (strumLine.keys ?? 4) + ",\n");

            buf.add("\n\t\t\t\"notes\":");
            buf.add("\n\t\t\t[");

            for (i in 0...notes.length)
            {
                var note:ChartNote = notes[i];

                var length:Float = (note.length == null || note.length < 0) ? 0.0 : note.length;

                buf.add("\n\t\t\t\t{\"t\": " + (note.time ?? 0.0) + ", \"d\": " + (note.direction ?? 0) + ", \"l\": " + length + ", \"k\": " + Json.stringify(note.kind ?? "default") + "}" + ((i == notes.length - 1) ? "" : ","));
            }

            buf.add("\n\t\t\t]");
            buf.add("\n\t\t}" + ((s == strumlines.length - 1) ? "" : ","));
        }

        buf.add("\n\t]\n");
        buf.add("}");

        return buf.toString();
    }

    /**
     * Serializes event data into the engine's events format,
     */
    public static function writeEvents(name:String, data:EventData):String
    {
        var events:Array<EventEntry> = [];

        if (data != null && data.events != null)
        {
            for (event in data.events)
                if (event != null) events.push(event);
        }

        var buf:StringBuf = new StringBuf();

        buf.add("{");
        buf.add("\n\t\"events\":\n\t[");

        for (e in 0...events.length)
        {
            var event:EventEntry = events[e];

            buf.add("\n\t\t{\"n\": " + Json.stringify(event.name ?? "") + ", \"t\": " + (event.time ?? 0.0) + ", \"v\": " + Json.stringify(event.variables ?? []) + "}" + ((e == events.length - 1) ? "" : ","));
        }

        buf.add("\n\t]\n");
        buf.add("}");

        return buf.toString();
    }

    /**
     * Resolves an asset key to the real file it exists in.
     */
    public static function resolveRealFile(assetKey:String):String
    {
        #if sys
        var path:String = Paths.getPath(assetKey);

        if (path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path))
            return path;
        #end

        return null;
    }

    /**
     * Saves converted data to the disk.
     */
    public static function saveConvertedFile(realPath:String, content:String):Bool
    {
        #if sys
        try
        {
            File.saveContent(realPath, content);
            return true;
        }
        catch (e:Dynamic)
        {
            trace('Failed to save converted file at $realPath: $e', "WARNING");
        }
        #end

        return false;
    }

    /**
     * Deletes a source file whose data has been fully converted into other files.
     */
    public static function removeSourceFile(realPath:String):Bool
    {
        #if sys
        try
        {
            FileSystem.deleteFile(realPath);
            return true;
        }
        catch (e:Dynamic)
        {
            trace('Failed to remove converted source at $realPath: $e', "WARNING");
        }
        #end

        return false;
    }
}
