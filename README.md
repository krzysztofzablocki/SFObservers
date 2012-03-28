Purpose
--------------
SFObservers is an category extension that adds auto removal for Observer pattern in NSNotificationCenter and KVO. By including this into your project, you no longer need to manually remove observers when observer object is deallocated. 

Supported OS & SDK Versions
-----------------------------

* iOS 4.0 (Xcode 4.3, Apple LLVM compiler 3.1)

ARC Compatibility
------------------

SFObservers automatically works with both ARC and non-ARC projects through conditional compilation. There is no need to exclude SFObserver files from the ARC validation process, or to convert SFObservers using the ARC conversion tool.

Installation
--------------

To use the SFObserver in your app, just drag the class files (demo files and assets are not needed) into your project. And include SFObservers.h in your project Prefix.pch file.
