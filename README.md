# ehc_builder

This codebase is designed to run eye-hand coordination (EHC) experiments using the Psychtoolbox library in Matlab. It provides a common interface for users to implement their own trials, eye trackers and manipulators, and includes a few basic trial types as examples.

## How it works

EHC experiments primarily consist of a series of `Trials`, which present distinct on-screen stimuli while evaluating the activity of both an eye and a limb with an `EyeTracker` and a `Manipulator`, respectively. Data is passed between these classes through a central `ExperimentManager`, which integrates incoming data to handle trial progression, while calling upon a `DisplayManager` to draw trial elements and feedback to the on-screen display. Experiments play out as follows:

* Pre-trial:
  1. `establish()` connections to all `EyeTracker` and `Manipulator` instances, and perform `calibrate()` routines as necessary.
  2. Before each round of a trial, call `Trial.generate()`, which generates a list of on-screen elements while defining the conditions necessary for success/failure.
  3. Display a set of elements defined in `Trial.intro`, while checking that the *primary* `Manipulator` (the first one specified) is in a designated home position (this is usually set in calibration). Instruct the player that they should fixate on a visual target, and display other text instructions if necessary.
  4. The trial will begin when both the *primary* `Manipulator` and the eye tracker have been held on the home position for a short time. Here, the operator may choose to manually zero the incoming eye-tracker data to the visual target --- a process known as *drift correction* --- or recalibrate the eye-tracker entirely.
* Trial:
  1. `poll()` data from both the `EyeTracker` and the `Manipulators`, if it is `available()`.
  2. Apply the calibration functions of both devices to the incoming raw data, to convert it from the sensor domain to the screen domain.
  3. Pass this data to `Trial.check()`, which checks whether the incoming data passes some series of conditions to count as a *success/timeout/failure*.
  4. If the display is ready to update, draw the list of on-screen elements specified by `Trial.elements`. Optionally draw the sensor-domain data to provide the user with gaze/manipulator feedback.
* Post-trial:
  1. Play audio and/or visual indicators of success/failure.
  2. If a round failed, save the trial elements, and replay the round after all other rounds are complete.
  3. Save the raw data along with a list of trial elements to an output structure for export.
  4. After all trials are complete, `close()` the hardware interfaces and shut down the experiment.

## Getting started

1. Download and install the latest version of [Matlab](https://www.mathworks.com/products/get-matlab.html?s_tid=gn_getml) (this build was written in R2022a).
2. Follow the instructions to download and install the latest version of [Psychtoolbox](http://psychtoolbox.org/download.html).
3. Clone or fork this repository.

## Running an experiment

To start an experiment, simply run `EHCBegin` from the command line, making sure to set an eye tracker, one or more manipulators (with the first one being the primary), and add a list of trials in the order that you want them to run.

## Practice trials

Practice trials are a special type of trial that can be run before regular trials, using the `ExperimentManager.addPractice()` function. Any trial implementing `TrialInterface` may be set as a practice trial, and is played in much the same way as regular trials, with only a few changes:

1. Post-trial feedback (success/failure beeps or color coding) is not provided.
2. Eye tracker/manipulator data is recorded, but not saved by default.

After each practice trial, an internal copy of the sensor recordings and outcomes of each trial are sent to the specific `Trial` class with a static `evaluatePractice()` function. The output from this function is saved in the final data file (see the Output Data Format section). This function (defined in `TrialInterface` can be overridden for many purposes, including adjusting class-wide target sizes based on player performance. 

*Note*: currently, only a single practice trial of each class is allowed, to avoid conflicts between class-wide adjustments. This may be adjusted in the future.

## Adding trial types

The following trials have already been implemented:
* `EmptyTrial`: a blank trial to be used for testing.
* `SingleShapeRingTrial`: a trial where a single radially-symmetric ring of shapes is presented, and the player must reach for the correct one.
* `NavonTask`: a trial where two Navon letters are presented, and the player must reach for the side containing a specific target letter (either as a local or global feature).
* `TraceShapeTrial`: a trial where the player must trace the outline of a shape presented in the center of the screen.

All trial classes must inherit from and implement the provided `TrialInterface`; see the class documentation for more details. In addition, all elements in the `Trial.elements` struct must include an `ElementType` property that is supported by `DisplayManager.drawElements()`. If you have special element types, make sure to update this function. The element types that are currently supported are:

* `hide`: a label which skips drawing the element. Used for when elements need to be added and removed quickly throughout a trial.
* `texture`: an image that can be pre-rendered for rapid drawing to the screen, generally used for filled shapes. While Psychtoolbox provides the `Screen('FillPoly')` function, this can be slow for complex and non-convex polygons, so pre-rendering a texture with `Screen('MakeTexture')` is a better idea. To create your own textures, see the `GenerateShapeBitmaps` helper function; the `DisplayManager` will automatically render all textures defined by the output of this function.
* `text`: a formatted text box to be drawn with the `Screen('DrawFormattedText')` function.
* `framepoly`: a set of vertices used to draw the outline of a polygon with the `Screen('FramePoly')` or `Screen('FrameOval')` functions.

Flexibility in trial paradigms can be coded into each trial, by writing custom `check()` subfunctions. For example, the `SingleShapeRingTrial` currently has 4 supported paradigms:
1. *Look-only*: the eye tracker is used to hit targets, and moving the manipulator too far out of home position results in a failure. A auditory cue signals that the player may begin gazing.
2. *Reach-only*: the manipulator is used to hit targets, and gazing too far away from the screen center results in a failure. A visual cue (disappearance of the center target) signals that the player may begin reaching.
3. *Free*: the manipulator is used to hit targets, and gaze can travel anywhere without restriction. Both cues are presented simultaneously at the start of each trial.
4. *Segmented*: split into two segments, consisting of a look-only segment (auditory cue) followed by a free reach (visual cue).

## Adding eye trackers

The following eye trackers have already been implemented:
* `NoEyeTracker`: a dummy class to be used for testing, or when no eye tracker is needed for the experiment.
* `WASDEyeTracker`: a debug class which substitutes the eye tracker with WASD controls.
* `EyeLink2`: an interface for the head-mounted [SR Research Eyelink II](https://www.sr-research.com/eyelink-ii/), which uses Psychtoolbox hardware libraries that can be downloaded [here](https://www.sr-support.com/thread-13.html).

All eye tracker classes must inherit from and implement the provided `EyeTrackerInterface`; see the class documentation for more details.

*Note*: currently, use of only one eye tracker at a time is supported. 

## Adding manipulators

The following manipulators have already been implemented:
* `NoManipulator`: a dummy class to be used for testing, or when no manipulator is needed for the experiment.
* `MouseCursor`: an interface which monitors the position of the mouse cursor and the status of mouse buttons using the Psychtoolbox `GetMouse` function. 
* `TouchScreen`: an interface which monitors a touchscreen and logs all touch events using the Psychtoolbox `TouchEventGet` function.
* `PolhemusLiberty`: an interface for the [Polhemus Liberty](https://polhemus.com/motion-tracking/all-trackers/liberty) 6-DOF position sensor, which assumes that position + orientation data is actively being published to a local TCP port. 

All manipulator classes must inherit from and implement the provided `ManipulatorInterface`; see the class documentation for more details. 

Multiple manipulators can be sampled/recorded at the same time by specifying a 1xN matrix of `Manipulator` objects. The first manipulator in the list will be used to progress from the pre-trial to the trial phase. *Keep in mind that adding more devices may lower sample rates.*

## Output data format

When starting an experiment, the user will be queried for their initials; this will generate a filepath at `data/<date>/<initials>_<time>.mat`, which will contain a struct called `Data`. The contents of `Data` are organized as follows:
* `NumTrials`: (int) the total number of trials in the experiment (**N**)
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
	* `homePosition`: (1x2 int) the XY coordinate used as a target for beginning trials
	* `homeRadius`: (int) the radius of the home zone
* `Manipulators`: (struct) contains information about the manipulator that was used
	* `Class`: (1x**M** cell) the names of all manipulator classes, in the order they were created
	* `calibrationFcn`: (1x**M** cell) functions for each manipulator that, when applied to raw sensor samples, convert them into screen-space coordinates; the first two columns of the output vector must be XY pixel coordinates relative to screen center
	* `homePosition`: (1x**M** cell) the XYZ coordinates used as home positions for beginning trials
	* `homeRadius`: (1x**M** cell) the radius of the home zone
* `PracticeData`: (1x**P** struct) contains information about the practice trials that were run, and the evaluated practice outcome returned from each trial.
	* `Class`: (char) the class of the practice trial that was run
	* `TargetAccuracy`: (float) the target accuracy specified by the operator, which was provided to the trial for evaluation
	* `Outcome`: (var) the outcome that was returned from each trial's `evaluatePractice()` function.
* `TrialData`: (1x**N** struct) contains information about the trials that were run, and the data collected during each trial
	* `Class`: (char) the class of the trial that was run
	* `NumRounds`: (int) the number of rounds in the trial (**R**)
	* `Timeout`: (double) the number of seconds that was set as the trial timeout
	* `Outcomes`: (1x**A** int) the outcome of each trial, defined as 1 for successes, 0 for timeouts, and -1 for failures
	* `Elements`: (**A**x1 cell) contains a struct of varying length for each trial, which stores information about the on-screen elements that were displayed for that trial, to be used by `DisplayManager.drawElements()`
	* `Targets`: (**A**x1 cell) contains a struct of varying length for each trial, which stores information about the specific on-screen elements that used as *success* conditions for that trial
	* `Failzones`: (**A**x1 cell) contains a struct of varying length for each trial, which stores information about the specific on-screen elements that used as *failure* conditions for that trial
	* `EyeTrackerData`: (**A**x1 cell) contains a double array of timestamped raw data that was polled from the eye tracker during each trial.
	* `ManipulatorData`: (**A**x**M** cell) contains double arrays of timestamped raw data that was polled from each manipulator during each trial.

**N**: number of trials\
**R**: number of rounds in a particular trial\
**A**: number of attempts in a particular trial (must be at least **R**)\
**M**: number of manipulators\
**P**: number of practice trials

## Known bugs

* Running Psychtoolbox on a Windows machine is widely known to lead to inaccurate timing and unpredictable bugs. I've done my best to work around these, but some of these issues are unavoidable.
	* The constructor for `DisplayManager` sets the Psychtoolbox `Screen('Verbosity')` setting to 0, suppressing many print statements. ONLY turn this on for debugging purposes; on some machines, these print statements will consistently screw up the timing of asynchronous screen updates, causing freezes/crashes.
	* Currently, the `DisplayManager.updateAsync()` function calls `Screen('AsyncFlipBegin')` with a scheduled time of half an IFI after when the function is called. This is the one workaround that I could find for the aforementioned freezing behavior. While this may skip some viable screen update frames, I'm willing to accept the delay to avoid crashes.
* Note that while the main loop asynchronously picks up data samples and updates the screen, this code does NOT contain any multithreading or multiprocessing. If your code takes too long to check `available()`, `poll()` or `drawElements()` to the screen, it WILL bottleneck the main loop, and may cause data loss if the sample rate of your hardware is particularly fast.

## Future ideas

* Add more experiment specifications to the dialog box at the start of the experiment, to be saved in the output data file.
* Allow multiple eye trackers to be specified.
---
Last updated: October 10, 2022 by Eric Hu
