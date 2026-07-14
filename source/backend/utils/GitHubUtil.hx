package backend.utils;

import haxe.Http;
import haxe.Json;

/**
 * A utility class giving you access to a bunch of info about a GitHub user/repository.
 */
class GitHubUtil
{
    /**
     * Fetches the latest commit from a given github repository.
     * @param owner The owner of the repository.
     * @param name The name of the repository.
     * @param branch The branch to read the latest commit from.
     * @param token The API Token of the owner (ONLY PUT THIS IF THE REPOSITORY IS PRIVATE WITH TRUSTED PEOPLE)
     * @param onComplete Called with the 7 character commit SHA once the request succeeds.
     */
    public static function fetchCommit(owner:String, name:String, ?branch:String = "main", ?token:String = "", onComplete:String->Void):Void
    {
        var req = new Http('https://api.github.com/repos/$owner/$name/branches/$branch');

        if (token != null && token != "")
            req.addHeader("Authorization", "Bearer " + token);

        req.addHeader("Accept", "application/vnd.github+json");
        req.addHeader("X-GitHub-Api-Version", "2022-11-28");
        req.addHeader("User-Agent", "RevEngine (API v" + Constants.API_VERSION + ")");

        req.onData = function(data:String)
        {
            try
            {
                var json:Dynamic = Json.parse(data);
                var sha:String = json.commit.sha;

                onComplete(sha.substring(0, 7));
            }
            catch (e:Dynamic)
                trace('Failed to parse GitHub commit data for $owner/$name: $e', "WARNING");
        };

        req.onError = function(error:String)
        {
            trace('Failed to fetch the latest commit for $owner/$name: $error', "WARNING");
        };

        #if sys
        ThreadUtil.execAsync(() -> req.request());
        #else
        req.request();
        #end
    }
}
