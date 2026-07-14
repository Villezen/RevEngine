package backend.modding;

import polymod.Polymod.PolymodError;
import polymod.Polymod.PolymodErrorType;

import backend.utils.WindowUtil;

class PolymodErrorHandler
{
    /**
     * Logs an error that the polymod backend detects [WIP]
     * @param error The error data.
     */
    public static function printError(error:PolymodError):Void
    {
        switch(error.code)
        {
            case MOD_MISSING_DIRECTORY | MOD_MISSING_ID:
                trace('Tried to load a mod that was not installed: ${error.message}', 'WARNING');
                WindowUtil.showError('Mod Load Error', error.message);

            case SCRIPT_PARSE_FAILED:
                trace('${error.message}', 'ERROR');
                WindowUtil.showError('Script Parsing Error', error.message);

            default:
                log(error.severity, error.message);
        }
    }

    /**
     * Logs a Polymod error into the console.
     * @param type The severity of the Polymod error.
     * @param message The message to display.
     */
    public static function log(type:PolymodErrorType, message:String)
    {
        switch (type)
        {
            case INFO: info(message);
            case WARNING: warning(message);
            case DEBUG: debug(message);
            case ERROR: error(message);
        }
    }

    public static function info(message:String):Void
    {
        trace('[INFO]: ' + message, "POLYMOD", true);
    }
    
    public static function debug(message:String):Void
    {
        trace('[DEBUG]: ' + message, "POLYMOD", true);
    }

    /**
     * Use the "WARNING" and "ERROR" types so they stand out more.
     */
    public static function warning(message:String):Void
    {
        trace('[POLYMOD]: ' + message, "WARNING", true);
    }
    
    public static function error(message:String):Void
    {
        trace('[POLYMOD]: ' + message, "ERROR", true);
    }
}