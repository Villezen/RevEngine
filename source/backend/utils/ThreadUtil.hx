package backend.utils;

import sys.thread.Deque;
import sys.thread.Thread;
import sys.thread.Mutex;

final class ThreadUtil
{
    /**
     * The maximum amount of threads that this class can use.
     */
    public static var maxThreads:Int = 4;

    /**
     * Threads in use for a process.
     */
    static var threads:Array<Thread> = [];

    /**
     * Pending async executions.
     */
    static var pendingExecs:Deque<Void->Void> = new Deque();

    /**
     * Thread in mutual exclusion.
     */
    static var threadMutex:Mutex = new Mutex();

    /**
     * Threads with an active task.
     */
    static var threadUsed:Int = 0;

    static function threadExecAsync():Void
    {
        var callback:Void->Void;

        while ((callback = pendingExecs.pop(true)) != null)
        {
            updateMutex(threadMutex, threadUsed, true);

            try
            {
                callback();
            }
            catch (e)
                trace("ASYNC THREADING ERROR: " + e.details(), "ERROR");
            
            updateMutex(threadMutex, threadUsed, false);
        }
    }

    /**
     * Acquires to the mutex, adds or removes to the used threads and then releases from the mutex.
     */
    static function updateMutex(mutex:Mutex, used:Int, add:Bool):Void
    {
        mutex.acquire();
        used += (add ? 1 : -1);
        mutex.release();
    }

    /**
     * Executes a function asynchronously.
     * @param func Function to execute.
     */
    public static function execAsync(?func:Void->Void):Void
    {
        // Stop execution in case func gets destroyed.
        if (func == null) 
        {
            return;
        }

        pendingExecs.add(func);
        threadMutex.acquire();

        var currentUsed:Int = threadUsed;
        var currentTotal:Int = threads.length;

        threadMutex.release();

        if (currentUsed < currentTotal || currentTotal >= maxThreads) 
        {
            return;
        }

        threadMutex.acquire();

        try
        {
            threads.push(Thread.create(threadExecAsync));
        }
        catch (e) 
            trace("ERROR WHILE ATTEMPTING TO PUSH THREAD: " + e.details(), "ERROR");
        
        threadMutex.release();
    }
}