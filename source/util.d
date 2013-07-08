module util;

import std.datetime;
import core.stdc.time;

import std.range;

SysTime unixTimeToSysTime(time_t unixTime)
{
	return SysTime(unixTimeToStdTime(unixTime));
}

time_t sysTimeToUnixTime(DateTime dateTime)
{	
	return SysTime(dateTime).toUnixTime();
}

void call(alias pred, Range)(Range range)
    if (isInputRange!(Range))
{
    foreach(r;range)
    {
        pred(r);
    }
}
