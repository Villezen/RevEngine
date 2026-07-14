package backend.utils;

import sys.thread.Deque;
import sys.thread.Thread;
import sys.thread.Mutex;

final class ThreadUtil
{
    public static var maxThreads:Int = 4;

    static var threads:Array<Thread> = [];
    static var pendingExecs:Deque<Void->Void> = new Deque();
    static var threadMutex:Mutex = new Mutex();
    static var threadUsed:Int = 0;

    /**
     * Creates a new Thread with an error handler.
     */
    public static function createSafe(func:Void->Void, autoRestart:Bool = false):Thread
    {
        try
        {
            return if (autoRestart) Thread.create(() ->
            {
                var restart = true;
                while (restart) try
                {
                    func();
                    restart = false;
                }
                catch (e) trace(e.details());
            })
            else Thread.create(() ->
            {
                try {func();}
                catch (e) trace(e.details());
            });
        }
        catch (e) trace("Failed to safely create a thread: " + e.details());

        return null;
    }

    static function threadExecAsync()
    {
        var callback:Void->Void;

        while ((callback = pendingExecs.pop(true)) != null)
        {
            threadMutex.acquire();
            threadUsed++;
            threadMutex.release();

            try 
            {
                callback();
            }
            catch (e)
                trace("[X] ASYNC THREADING ERROR: " + e.details());

            threadMutex.acquire();
            threadUsed--;
            threadMutex.release();
        }
    }

    public static function execAsync(func:Void->Void)
    {
        if (func == null) return;

        pendingExecs.add(func);

        threadMutex.acquire();

        var currentUsed = threadUsed;
        var currentTotal = threads.length;

        threadMutex.release();

        if (currentUsed >= currentTotal)
        {
            if (currentTotal >= maxThreads) 
                return;

            threadMutex.acquire();
            try
            {
                var thread = Thread.create(threadExecAsync);
                threads.push(thread);
            }
            catch (e) 
                trace(e.details());
            
            threadMutex.release();
        }
    }
}