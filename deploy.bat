REM SYNTAX: deploy wowVersion ex: deploy 15595
robocopy . ../packetparser_app/ yawr_packetparser.dll
cd ../packetparser_app/
del yawr_packetparser_%1.dll
ren yawr_packetparser.dll yawr_packetparser_%1.dll
cd ../packetparser/