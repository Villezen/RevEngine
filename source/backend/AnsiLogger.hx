package backend;

import haxe.Log;
import haxe.PosInfos;

/**
 * Class used to handled ANSI Tracing :)
 */
class AnsiLogger
{
    /**
     * Copy of the original trace function for fallback.
     */
    static var originalTrace:Dynamic->?PosInfos->Void;

    /**
     * Replaces the base trace function with a custom one.
     */
    public static function init():Void
    {
        originalTrace = Log.trace;
        Log.trace = customTrace;
    }

    /**
     * A custom trace function using the ANSI escape code system to make the trace more detailed. 
     * @param v The value to trace.
     * @param infos Any additional params.
     */
    static function customTrace(v:Dynamic, ?infos:PosInfos):Void
    {
        var msg = Std.string(v);
        
        var level = "TRACE";
        var bgColor = "100";
        var fgColor = "97";
    
        var hidePosition:Bool = false;

        if (infos != null)
        {
            if (infos.fileName != null) 
            {
                if (StringTools.startsWith(infos.fileName, "hscriptClass(")) 
                {
                    var cleanName = infos.fileName;
                    cleanName = StringTools.replace(cleanName, "hscriptClass(assets/scripts/", "");
                    cleanName = StringTools.replace(cleanName, ")", "");

                    infos.fileName = cleanName;
                }
            }            

            // What 'LEVEL' the trace is, and its corresponding colors.
            if (infos.customParams != null && infos.customParams.length > 0)
            {
                var tag = Std.string(infos.customParams[0]).toUpperCase();
                switch (tag)
                {
                    case "WARNING":
                        level = "WARNING";
                        bgColor = "43";
                        fgColor = "30";
                    case "ERROR":
                        level = "ERROR";
                        bgColor = "41";
                        fgColor = "37";
                    case "SUCCESS":
                        level = " OK ";
                        bgColor = "42";
                        fgColor = "30";
                    case "PRELOAD":
                        level = "PRELOAD";
                        bgColor = "100";
                        fgColor = "97";
                    case "POLYMOD":
                        level = "POLYMOD";
                        bgColor = "46";
                        fgColor = "30";
                    case "INFO":
                        level = "INFO";
                        bgColor = "104";
                        fgColor = "97";
                }

                // Hides the position of the trace.
                if (Std.isOfType(infos.customParams[1], Bool))
                {
                    hidePosition = (cast infos.customParams[1]) ?? false;
                }
            }
        }

        // Makes errors stand out more by giving them spacing in the console.
        var spacing:String = level != 'ERROR' ? '' : '\n';
        
        var reset = "\x1b[0m";
        var box = '\x1b[${bgColor};${fgColor}m ${level} ${reset}';
        var position = infos == null ? "(unknown position)" : '(${infos.fileName}:${infos.lineNumber}) | ';
        if (hidePosition || level == 'PRELOAD') position = "";

        #if sys
        Sys.println('${spacing}${box} ${position}${spacing}${msg}${spacing}');
        #else
        originalTrace('[${level}] ${position} | ${msg}', infos);
        #end
    }
}