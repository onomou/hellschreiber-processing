
# hellschreiber-processing

A meager attempt at a Feld Hell decoder program, with
 the end goal of TX/RX in a cross-platform, user-friendly form...
 Really, just an excuse to learn something new and practice writing code.
 

## Notes about the concept

 Receive is 7 scan lines per character, 14 pixels per scan line.
 

        I   II  III IV  V   VI  VII  
    13-14  :   :   :   :   :   :   :   ^  <- 57.14/14 = 4.08ms per pixel
    11-12  :   :   :   :   :   :   :   |
     9-10  :   :   :   :   :   :   :   |
     7-8   :   :   :   :   :   :   :   400/7 = 57.14ms
     5-6   :   :   :   :   :   :   :   |
     3-4   :   :   :   :   :   :   :   |
     1-2   :   :   :   :   :   :   :   v
        <======== 400ms ==========>

## Compatibility
Only tested on Windows so far.
I use [Androidomatic Keyer
](https://play.google.com/store/apps/details?id=com.templaro.opsiz.aka) to test receiving messages.

## Credits

 - Thanks to Frank Dörenberg's [Hellschreiber pages
   ](https://www.nonstopsystems.com/radio/hellschreiber.htm) on how it
   all works.
 - Uses [ Processing](https://processing.org/) with
 - [ControlP5](http://www.sojamo.de/libraries/controlP5/) for GUI
   controls and
 - [Minim](http://code.compartmental.net/tools/minim/) for
   audio processing.
