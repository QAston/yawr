YAWR - World of Warcraft server software
====================

About
---------------------

Yet Another Wowd Rewrite or YAWR in short is a research project focused on creating a World of Warcraft game server implementation in D programming language.

Goals
---------------------

 - create a World of Warcraft game server
 - create a set of wow related libraries for reuse
 - create a set of wow related tools
 - learn a lot by developing such software
 - focus on making things right rather than making things work - it's a research project after all
 - have a lot of fun doing all this
 
NonGoals
--------------------
 
 - this project is not an attempt to leech money from Blizzard's work
 - authors do not support using the software in an illegal manner, which includes commercial use of the software

Structure
---------------------

YAWR consists of several subprojects:

 - authserver - server allowing 
 - authprotocol lib - library providing modules for apps using wow authentication protocol
 - packetparser_app - application capable of parsing client-server communication dumps
 - packetparser lib - library providing parser for each game version
 - wowprotocol lib - library providing modules for apps using wow game protocol
 - wowdefs lib - library providing modules with definitions of constants and structres valid for a given gameversion
 - util lib - library with generic utils
 
Dependencies
---------------------

 - vibe.d asynchronyous I/O library
 - mysql-native providing interface to mysql for d
 - dub package manager

Why such name?
---------------------

The project is called Yet Another Wowd Rewrite beacause it comes after several projects existing before which aimed for similar goals - providing a better software than MaNGOS/TrinityCore/Arcemu and other WoW Daemon (WowD) based projects. 
Most notable examples of such rewrites are WCell and Encore, there were several other smaller projects too.
Their main motivation to create a replacement for WowD based projects were issues with the design of the software which could not be fixed easily in the codebase - like making the server scalable.

How can you help?
---------------------

Creating a gameserver from scratch is a huge undertaking. There's lots of features to add and design decisions to make. A lot about internal game mechanics is unknown, therefore a lot of reverse engineering needs to be done.
Possibly a gui client for the game could be made. Definitely you can find here something that's interesting to you to implement. Feel encouraged to create pull requests and issues on the github repository. 

License
---------------------
This project is licensed under GNU GPLv2 (or later) license. See COPYING for details.

Authors and Copyright
---------------------
Copyright (C) 2013 YAWR

Some parts of the code are adapted parts of C++ codebase taken from TrinityCore project, which codebase has a long history:
- Copyright (C) 2008-2013 TrinityCore <http://www.trinitycore.org/>
- Copyright (C) 2005-2009 MaNGOS <http://getmangos.com/>
- Copyright (C) WoW Daemon Team, 2004

YAWR is a small project which stands on the shoulders of giants.
Many projects have contributed to the overall knowledge of the World of Warcraft protocol and game internals - which is used in this project:
-TrinityCore -  http://trinitycore.org
-SkyFire - http://www.projectskyfire.org/
-MaNGOS - http://getmangos.com/
-WCell - http://wcell.org/
-Arcemu - http://arcemu.org/
... and others - could not possibly mention them all.