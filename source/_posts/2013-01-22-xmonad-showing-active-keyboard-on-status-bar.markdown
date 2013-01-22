---
layout: post
title: "xmonad - Showing active keyboard on status bar"
date: 2013-01-22 16:38
comments: true
categories: xmonad haskell xkb
---

**[xmonad](http://xmonad.org/)** is tiling X11 window manager written & configured in Haskell.

After installing & configuring xmonad to my taste I missed one little thing: **showing currently active keyboard layout on top**.

After googling around & trying out some shell scripts I found this little program in github called [XKB-SWITCH](https://github.com/ierton/xkb-switch).

It allows easily to set the keyboard layout & also programmatically query the currently active keyboard layout. I already have my xmonad configured to switch keyboard layout by holding down both Shift keys so I just needed use this utility to query currently active layout.

It was just plain simple to integrate this little program with **xmobar**. Just add this line to your xmobar configuration, under the **commands** function:

{% codeblock lang:haskell %}

Run Com "xkb-switch" [] "kb" 10

{% endcodeblock %}

Now, restart xmonad (modm + q) and that's it. Your current keyboard layout should now be sitting on the status bar.

Here is a screenshot of mine (the result is surrounded by red rectangle)!

![Screenshot of mine](/files/img/xmonad-statusbar-kb-layout.jpg)

