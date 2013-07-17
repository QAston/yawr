module util.time;

import std.datetime;
import core.stdc.time;

/+
 + Converts given unit time stamp to UTC SysTime
 +/
SysTime unixTimeToSysTimeUTC(time_t unixTime)
out(result) {
    assert(result.toUnixTime == unixTime);
}
body {
	return SysTime(unixTimeToStdTime(unixTime)).toUTC;
}
