package game;

import game.notes.Note;

import backend.utils.MathUtil;

/**
 * An enum of every possible timing-based rating a player can recieve from hitting a note.
 */
enum NoteJudgement
{
    SICK;
    GOOD;
    BAD;
    SHIT;
    NONE;
}

/**
 * A class made to track and calculate all performance telemetry during a song.
 */
class PlayMetrics
{
    /**
     * The internal name of the song currently being played.
     */
    private var song:String = "";

    /**
     * The cumulative score earned by the player.
     */
    public var score(default, set):Int = 0;

    function set_score(value:Int):Int
    {
        return score = value;
    }

    /**
     * Total amount of notes missed.
     */
    public var misses:Int = 0;

    /**
     * Per-judgement hit counts.
     */
    public var sick:Int = 0;
    public var good:Int = 0;
    public var bad:Int = 0;
    public var shit:Int = 0;

    /**
     * The highest combo reached during the song.
     */
    public var maxCombo:Int = 0;

    /**
     * The total number of player notes in the chart, set once at song start.
     */
    public var totalNotes:Int = 0;

    /**
     * Overall accuracy, judged by hit timings.
     */
    public var accuracy(default, set):Float = 0.00;

    function set_accuracy(value:Float):Float
    {
        return (accuracy = MathUtil.limitFloat(value, 0, 100));
    }

    /**
     * The player's current health value.
     */
    public var health(default, set):Float = Constants.MAX_HEALTH / 2;

    function set_health(value:Float):Float 
    {
        return (health = MathUtil.limitFloat(value, Constants.MIN_HEALTH, Constants.MAX_HEALTH));
    }

    /**
     * The current number of consecutive note hits without a miss.
     */
    public var combo:Int = 0;

    /**
     * Weighted total of hit notes used for accuracy calculations.
     */
    public var hitNotes:Float = 0;

    /**
     * Total number of notes that have passed the strumline. Used for accuracy calculations.
     */
    public var playedNotes:Int = 0;

    /**
     * The last rating that has been registered.
     */
    public var lastRating:NoteJudgement;

    /**
     * Creates a new metrics tracker for a specific song.
     * @param song The name of the song.
     */
    public function new(song:String)
    {
        this.song = song;
        this.health = Constants.MAX_HEALTH / 2;
    }

    /**
     * Determines which `NoteJudgement` a hit falls into based on timing offset.
     * @param ms The time difference in milliseconds between the hit and the target time.
     * @return The resulting `NoteJudgement`. Returns `NONE` if input is invalid.
     */
    public function calculateRating(ms:Float)
    {
        if (Math.isNaN(ms) || !Math.isFinite(ms)) 
            return NoteJudgement.NONE;

        var diff:Float = Math.abs(ms);

        if (diff <= Constants.RATING_MAP.get(NoteJudgement.SICK))
            return NoteJudgement.SICK;
            
        else if (diff <= Constants.RATING_MAP.get(NoteJudgement.GOOD))
            return NoteJudgement.GOOD;
            
        else if (diff <= Constants.RATING_MAP.get(NoteJudgement.BAD))
            return NoteJudgement.BAD;

        return NoteJudgement.SHIT;
    }

    /**
     * Updates the running accuracy percantage.
     */
    public function calculateAccuracy()
    {
        playedNotes++;
		accuracy = hitNotes / playedNotes * 100;
    }

    /**
     * Processes a successful note hit.
     * @param rating The `NoteJudgement` received for the hit.
     */
    public function judgeRating(rating:NoteJudgement)
    {
        var map = Constants.JUDGEMENT_MAP.get(rating);
        lastRating = rating;

        combo++;

        if (combo > maxCombo)
            maxCombo = combo;

        switch (rating)
        {
            case SICK: sick++;
            case GOOD: good++;
            case BAD: bad++;
            case SHIT: shit++;
            default:
        }

		score += Std.int(map[1]);
		health += map[0] / 100.0 * 2;
        hitNotes += map[2];
    }

    /**
     * Processes the gradual score & health gain while holding a sustain.
     */
    public function hold(elapsed:Float)
    {
        score += Std.int(Constants.SUSTAIN_SCORE_GAIN_PER_SEC * elapsed);
        health += Constants.SUSTAIN_HEALTH_GAIN_PER_SEC * elapsed;
    }

    /**
     * Processes a missed note.
     */
    public function miss()
    {
        combo = 0;

		health -= Constants.MISS_HEALTH_LOSS;
		score -= Constants.MISS_SCORE_LOSS;

		misses++;
    }
}