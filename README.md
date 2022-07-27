# ehc_builder

This codebase is designed to run eye-hand coordination (EHC) experiments using the Psychtoolbox library in Matlab. It provides a common interface for users to implement their own trials, eye trackers and manipulators, and includes a few basic trial types as examples.

## How it works

EHC experiments primarily consist of a series of `Trials`, which present distinct on-screen stimuli while evaluating the activity of both an eye and a hand analogue with an `EyeTracker` and a `Manipulator`, respectively. Data is passed between these classes through a central `ExperimentManager`, which integrates incoming data to handle trial progression, while calling
upon a `DisplayManager` to draw trial elements and feedback to the on-screen display. Experiments play out as follows:

* Pre-trial:
  1. `establish()` connections to all hardware interfaces, and perform `calibrate()` routines as necessary.
  2. Before each round of a trial, call `Trial.generate()`, which generates a list of on-screen elements while defining the conditions necessary for success/failure.
  3. Display a set of elements defined in `Trial.intro`, while checking that the `Manipulator` is in a designated start position (usually a target in the center of the screen). Instruct the player that they should fix their vision upon this target, and display other text instructions if necessary.
  4. After the `Manipulator` has been held on the center target for a short time, zero the incoming eye-tracker data to the center of the screen, a process known as *drift correction*. The trial is now ready to begin.
* Trial:
  1. `poll()` data from both the `EyeTracker` and the `Manipulator`, if it is `available()`.
  2. Apply the calibration functions of both devices to the incoming raw data, to convert it from the sensor domain to the screen domain.
  3. Pass this data to `Trial.check()`, which checks whether the incoming data passes some series of conditions to count as a *success/timeout/failure*.
  4. If the display is ready to update, draw the list of on-screen elements specified by `Trial.elements`. Optionally draw the sensor-domain data to provide the user with gaze/manipulator feedback.
* Post-trial:
  1. Save the raw data along with a list of trial elements to an output structure for export.
  2. After all trials are complete, `close()` the hardware interfaces and shut down the experiment.

## Getting started

1. Download and install the latest version of [Matlab](https://www.mathworks.com/products/get-matlab.html?s_tid=gn_getml) (this build was written in R2022a).
2. Follow the instructions to download and install the latest version of [Psychtoolbox](http://psychtoolbox.org/download.html).
3. Clone or fork this repository.

## Running an experiment

To start an experiment, simply run `EHCBegin` from the command line, making sure to set an eye tracker, manipulator, and add a list of trials in the order that you want them to run.
Some hardware interfaces (such as `PolhemusLiberty`) may skip calibration routines based on the presence of calibration files; to force calibrations to run, make sure to delete these files.

## Adding trial types

The following trials have already been implemented:
* `EmptyTrial`: a blank trial to be used for testing.
* `SingleShapeRingTrial`: a trial where a single radially-symmetric ring of shapes is presented, and the player must reach for the correct one.
* `NavonTask`: a trial where two Navon letters are presented, and the player must reach for the side containing a specific target letter (either as a local or global feature).
* `TraceShapeTrial`: a trial where the player must trace the outline of a shape presented in the center of the screen.

All trial classes must inherit from and implement the provided `TrialInterface`; see the class documentation for more details. In addition, all elements in the `Trial.elements` struct must include an `ElementType` property that is supported by `DisplayManager.drawElements()`. If you have special element types, make sure to update this function. The element types that are currently supported are:
* `texture`: an image that can be pre-rendered for rapid drawing to the screen, generally used for filled shapes. While Psychtoolbox provides the `Screen('FillPoly')` function, this can be slow for complex and non-convex polygons, so pre-rendering a texture with `Screen('MakeTexture')` is a better idea. To create your own textures, see the `GenerateShapeBitmaps` helper function; the `DisplayManager` will automatically render all textures defined by the output of this function.
* `text`: a formatted text box to be drawn with the `Screen('DrawFormattedText')` function.
* `framepoly`: a set of vertices used to draw the outline of a polygon with the `Screen('FramePoly')` or `Screen('FrameOval')` functions.

## Adding eye trackers

The following eye trackers have already been implemented:
* `NoEyeTracker`: a dummy class to be used for testing, or when no eye tracker is needed for the experiment.
* `EyeLink2`: an interface for the head-mounted [SR Research Eyelink II](https://www.sr-research.com/eyelink-ii/), which uses Psychtoolbox hardware libraries that can be downloaded [here](https://www.sr-support.com/thread-13.html).

All eye tracker classes must inherit from and implement the provided `EyeTrackerInterface`; see the class documentation for more details.

## Adding manipulators

The following manipulators have already been implemented:
* `NoManipulator`: a dummy class to be used for testing, or when no manipulator is needed for the experiment.
* `TouchScreenMouseCursor`: an interface which monitors the position of the mouse cursor and the status of mouse buttons using the Psychtoolbox `GetMouse` function. Can theoretically also be used with a touchscreen, although I haven't dont any thorough testing in this regard.
* `PolhemusLiberty`: an interface for the [Polhemus Liberty](https://polhemus.com/motion-tracking/all-trackers/liberty) 6-DOF position sensor, which assumes that position + orientation data is actively being published to a local TCP port. 

All manipulator classes must inherit from and implement the provided `ManipulatorInterface`; see the class documentation for more details.


## Output data format

When starting an experiment, the user will be queried for their initials; this will generate a filepath at `data/<date>/<initials>_<time>.mat`, which will contain a struct called `Data`. The contents of `Data` are organized as follows:

* `NumTrials`: (int) the number of trials in the experiment **N**
* `Display`: (struct) contains information about the display that the experiment was run on
	* `screen`: (int) the index of the screen returned by Psychtoolbox
	* `window`: (int) the index of the window generated by Psychtoolbox
	* `white`, `black`: (double) the float weights of white and black on the display monitor
	* `bgColor`: (1x3 double) an RGB triplet of the background color, valued between `white` and `black`
	* `windowRect`: (1x4 int) pixel boundaries of the active window in *[left, top, bottom, right]* form
	* `xMax`, `yMax`: (int) max pixel boundaries of the active window
	* `xCenter`, `yCenter`: (int) pixel values of the screen center
	* `ifi`: (double) the inter-frame interval of the active display, in seconds
* `EyeTracker`: (struct) contains information about the eye tracker that was used
	* `Class`: (char) the name of the eye tracker class
	* `calibrationFcn`: (function_handle) a function that, when applied to raw sensor samples, converts them into screen-space coordinates; the first two columns of the output vector must be XY pixel coordinates relative to screen center
* `Manipulator`: (struct) contains information about the manipulator that was used
	* `Class`: (char) the name of the manipulator class
	* `calibrationFcn`: (function_handle) a function that, when applied to raw sensor samples, converts them into screen-space coordinates; the first two columns of the output vector must be XY pixel coordinates relative to screen center
* `TrialData`: (1x**N** struct) contains information about the trials that were run, and the data collected during each trial
	* `NumRounds`: (int) the number of rounds in the trial **M**
	* `Timeout`: (double) the number of seconds that was set as the trial timeout
	* `Outcomes`: (1x**M** int) the outcome of each trial, defined as 1 for successes, 0 for timeouts, and -1 for failures
	* `Elements`: (**M**x1 cell) contains a struct of varying length for each trial, which stores information about the on-screen elements that were displayed for that trial, to be used by `DisplayManager.drawElements()`
	* `Targets`: (**M**x1 cell) contains a struct of varying length for each trial, which stores information about the specific on-screen elements that used as *success* conditions for that trial
	* `Failzones`: (**M**x1 cell) contains a struct of varying length for each trial, which stores information about the specific on-screen elements that used as *failure* conditions for that trial
	* `EyeTrackerData`: (**M**x1 cell) contains a double array of timestamped raw data that was polled from the eye tracker during each trial.
	* `ManipulatorData`: (**M**x1 cell) contains a double array of timestamped raw data that was polled from the manipulator during each trial.

## Known bugs

* Running Psychtoolbox on a Windows machine is widely known to lead to inaccurate timing and unpredictable bugs. I've done my best to work around these, but some of these issues are unavoidable.
	* The constructor for `DisplayManager` sets the Psychtoolbox `Screen('Verbosity')` setting to 0, suppressing many print statements. ONLY turn this on for debugging purposes; on some machines, these print statements will consistently screw up the timing of asynchronous screen updates, causing freezes/crashes.
	* Currently, the `DisplayManager.updateAsync()` function calls `Screen('AsyncFlipBegin')` with a scheduled time of half an IFI after when the function is called. This is the one workaround that I could find for the aforementioned freezing behavior. While this may skip some viable screen update frames, I'm willing to accept the delay to avoid crashes.
* Note that while the main loop asynchronously picks up data samples and updates the screen, this code does NOT contain any multithreading or multiprocessing. If your code takes too long to check `available()`, `poll()` or `drawElements()` to the screen, it WILL bottleneck the main loop, and may cause data loss if the sample rate of your hardware is particularly fast.

## Future ideas

* Add more experiment specifications to the dialog box at the start of the experiment, to be saved in the output data file.
* Add a way to force calibration functions to run each time even if calibration files are present, to avoid having to delete them each time.

---
Last updated: July 26, 2022 by Eric Hu