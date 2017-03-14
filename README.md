PunditBot
=========

This is a fork of [jeremybmerrill's punditbot](https://github.com/jeremybmerrill/punditbot).

It doesn't add any functionality to the original.
In fact, I've probably broken some things that worked just fine before I came along.

All I'm doing is moving code around to improve my understanding of [an NLG pipeline](https://github.com/simplenlg/simplenlg/wiki/Section%20XV%20%E2%80%93%20Appendix%20A%20%E2%80%93%20NLG%20and%20SimpleNLG).
I'm mainly trying to improve the separation of concerns between the Document Planning, Microplanning, and Surface Realiztion steps.

If I do a good job, this will result in improved testability of each step, though I probably won't get around to actually writing many tests.

If I do a great job, this will result in an NLG architecture I'll want to re-use on my own projects.
