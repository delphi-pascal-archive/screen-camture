Screen Cam Component (recording screen activity to video) 

I developed this screen cam component with delphi (captures the activity on a screen or delphi form and writes it into an AVI file; it supports all compressors; the program contains code derived from RenderSoft CamStudio 1.0 OPENSOURCE). 

I'm using a TThread for the recording function and a "transparent" window for a flashing frame. This window is always on top of all windows and only has a frame as window region (Frame is set up by SetWindowRgn). In the recording function I call a paint method of the flashing window for every frame (paintBorder). 

If there's anybody who would like to share some time in improving something or just try it out, please send me an email!

Please also notice the License agreeements from CamStudio 1.0 OPENSOURCE:
"This product is FREEWARE and you are free to duplicate and distribute this software through the internet or any preferred media.
If you create an product that contains code derived from CamStudio, you are free to distribute it for any purposes, including commercial purposes. However, your product must include an acknowledgement that mention it contains code from RenderSoft CamStudio. A simple statement like "Part of this product is derived from RenderSoft CamStudio" in the AboutBox will do. You are not obliged to reveal the source code of your derived product but are encouraged to do so."


Thanks,

Alexander

alexander_grau@gmx.de

Keep on hacking!
