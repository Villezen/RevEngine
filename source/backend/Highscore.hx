package backend;

typedef ScoreTallies =
{
    var sick:Int;
    var good:Int;
    var bad:Int;
    var shit:Int;
    var missed:Int;
    var combo:Int;
    var maxCombo:Int;

    var totalNotesHit:Int;
    var totalNotes:Int;
}

typedef ScoreRecord =
{
    var score:Int;
    var tallies:ScoreTallies;
}

class Highscore
{
    public static inline function formatKey(songId:String, difficulty:String = "normal", ?variation:String):String
    {
        if (variation == null) variation = "";
        return '$songId:$difficulty$variation';
    }

    public static function getScore(songId:String, difficulty:String = "normal", ?variation:String):Null<ScoreRecord>
    {
        return Configs.HIGHSCORES.get(formatKey(songId, difficulty, variation));
    }

    public static function getScoreValue(songId:String, difficulty:String = "normal", ?variation:String):Int
    {
        var record:Null<ScoreRecord> = getScore(songId, difficulty, variation);
        return (record == null) ? 0 : record.score;
    }

    public static function getClearPercent(songId:String, difficulty:String = "normal", ?variation:String):Float
    {
        var record:Null<ScoreRecord> = getScore(songId, difficulty, variation);
        return (record == null) ? 0.0 : tallyCompletion(record.tallies);
    }

    public static function isNewHighscore(songId:String, difficulty:String, variation:String, score:Int):Bool
    {
        var record:Null<ScoreRecord> = getScore(songId, difficulty, variation);
        return (record == null) ? true : score > record.score;
    }

    public static function saveScore(songId:String, difficulty:String, variation:String, record:ScoreRecord):Bool
    {
        var key:String = formatKey(songId, difficulty, variation);
        var previous:Null<ScoreRecord> = Configs.HIGHSCORES.get(key);

        var isBetterScore:Bool = (previous == null) || (record.score > previous.score);

        if (previous == null)
        {
            Configs.HIGHSCORES.set(key, record);
        }
        else
        {
            var bestScore:Int = (previous.score > record.score) ? previous.score : record.score;
            var bestTallies:ScoreTallies = (tallyCompletion(previous.tallies) > tallyCompletion(record.tallies)) ? previous.tallies : record.tallies;

            Configs.HIGHSCORES.set(key, {score: bestScore, tallies: bestTallies});
        }

        Configs.save();
        return isBetterScore;
    }

    public static function tallyCompletion(?tallies:ScoreTallies):Float
    {
        if (tallies == null || tallies.totalNotes <= 0) return 0.0;

        var raw:Float = (tallies.sick + tallies.good - tallies.missed) / tallies.totalNotes;
        return Math.max(0, Math.min(1, raw));
    }

    public static function blankTallies():ScoreTallies
    {
        return
        {
            sick: 0,
            good: 0,
            bad: 0,
            shit: 0,
            missed: 0,
            combo: 0,
            maxCombo: 0,
            totalNotesHit: 0,
            totalNotes: 0
        };
    }
}
