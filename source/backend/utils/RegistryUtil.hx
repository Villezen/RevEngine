package backend.utils;

import json2object.Error;
import json2object.ErrorUtils;

class RegistryUtil
{
    public static function reportErrors(file:String, errors:Array<Error>):Void
    {
        if (errors == null || errors.length == 0) return;

        var relevant:Array<Error> = [];

        for (error in errors)
        {
            switch (error)
            {
                case UnknownVariable(_, _): 
                default: relevant.push(error);
            }
        }

        if (relevant.length > 0)
            trace('Problems found while parsing "$file":\n' + ErrorUtils.convertErrorArray(relevant), "WARNING");
    }
}
