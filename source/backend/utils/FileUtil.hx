package backend.utils;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

class FileUtil
{
    public static function copyFolder(sourcePath:String, targetPath:String, ?onComplete:Void->Void):Void
    {
        try
        {
            var folderName:String = Path.withoutDirectory(sourcePath);
            var finalTargetPath:String = Path.join([targetPath, folderName]);
        
            Paths.createDirectory(finalTargetPath);

            for (item in FileSystem.readDirectory(sourcePath))
            {
                var sourceItemPath = Path.join([sourcePath, item]);
                var targetItemPath = Path.join([finalTargetPath, item]);

                if (FileSystem.isDirectory(sourceItemPath))
                    copyFolder(sourceItemPath, finalTargetPath);
                else
                    File.copy(sourceItemPath, targetItemPath);
            }

            if (onComplete != null)
                onComplete();
        }
        catch (e:Dynamic)
        {
            trace("Error copying files: " + e, "ERROR");
        }
    }
}