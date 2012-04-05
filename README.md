Purpose
--------------
SFObservers is an category extension that adds auto removal for Observer pattern in NSNotificationCenter and KVO. By including this into your project, you no longer need to manually remove observers when observer object is deallocated. 
By default it also prevents adding more than once the same observer - parameters pair, it can be disabled by setting SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS to 1 in SFObservers.h

Supported OS & SDK Versions
-----------------------------

* iOS 4.0 (Xcode 4.3, Apple LLVM compiler 3.1)

ARC Compatibility
------------------

SFObservers automatically works with both ARC and non-ARC projects through conditional compilation. There is no need to exclude SFObserver files from the ARC validation process, or to convert SFObservers using the ARC conversion tool.

Installation
--------------

To use the SFObserver in your app, just drag the class files (demo files and assets are not needed) into your project. And include SFObservers.h in your project Prefix.pch file.
There is no need to call custom methods, you can include it into existing project and it will work fine.
If you want to allow adding the same observer - parameters pairs, set SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS to 1 in SFObservers.h

Tests
--------------

Repository contains 2 sample projects with some unit tests, one is using ARC and other not. 
Also you can change SF_OBSERVERS_LOG_ORIGINAL_METHODS value to 1 if you would like to log original methods getting called.