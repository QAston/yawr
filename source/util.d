module util;

import std.datetime;
import core.stdc.time;

SysTime unixTimeToSysTime(time_t unixTime)
{
	return SysTime(unixTimeToStdTime(unixTime));
}

time_t sysTimeToUnixTime(DateTime dateTime)
{	
	return SysTime(dateTime).toUnixTime();
}
