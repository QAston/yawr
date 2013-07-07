Yet Another Wowd Rewrite
====================

About
---------------------

Yet Another Wowd Rewrite or YAWR in short is a research project focused on creating a World of Warcraft game server implementation in D programming language.

The project is called Yet Another Wowd Rewrite beacause it comes after several projects existing before which aimed for similar goals - providing a better software than MaNGOS/TrinityCore/Arcemu and other WoW Daemon based projects. 
Most notable examples of such rewrites are WCell and Encore, there were several other smaller projects too. Their main motivation to create a replacement for WowD based projects were issues with the design of the software which could not be fixed easily on such large codebase.
For example TrinityCore/MaNGOS/Arcemu and other wowd derivatives started as a single threaded application, with multithreading added much later on top of a single threaded codebase. This approach provides a working server, yet with many interdependencies between modules (this is typical to a single threaded application) it's very difficult to synchronize things correctly.

This project tries to step aside and design with experience which was obtained from the past.

License
---------------------
This project is licensed under GNU GPLv2 (or later) license. See COPYING for details.

Authors and Copyright
---------------------
Copyright (C) 2013 YAWR

YAWR is a small project which stands on the shoulders of giants.
Many projects have contributed to the overall knowledge of the World of Warcraft protocol and game internals - which is used in this project:
-TrinityCore -  http://trinitycore.org
-SkyFire - http://www.projectskyfire.org/
-MaNGOS - http://getmangos.com/
-WCell - http://wcell.org/
-Arcemu - http://arcemu.org/
... and others - could not possibly mention them all.

Some parts of the code are adapted parts of C++ codebase taken from TrinityCore project, which codebase has a long history:
- Copyright (C) 2008-2013 TrinityCore <http://www.trinitycore.org/>
- Copyright (C) 2005-2009 MaNGOS <http://getmangos.com/>
- Copyright (C) WoW Daemon Team, 2004