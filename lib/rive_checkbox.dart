library rive_checkbox;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart';

class RiveCheckbox extends StatefulWidget {
  static const _onAnimationName = 'On';
  static const _offAnimationName = 'Off';
  static const _unknownAnimationName = 'Unknown';
  final String animation;
  final String animationOn;
  final String animationOff;
  final String animationUnknown;
  final bool value;
  final bool tristate;
  final bool useArtboardSize;
  final double width;
  final double height;
  final Function(bool) onChanged;

  const RiveCheckbox({
    Key key,
    this.onChanged,
    this.tristate = false,
    this.useArtboardSize = false,
    this.animation,
    bool value,
    this.width,
    this.height,
    this.animationOn = _onAnimationName,
    this.animationOff = _offAnimationName,
    this.animationUnknown = _unknownAnimationName,
  })  : this.value = value ?? (tristate ? null : false),
        super(key: key);

  @override
  _RiveCheckboxState createState() => _RiveCheckboxState();
}

class _RiveCheckboxState extends State<RiveCheckbox> {
  bool currentState;
  Artboard _riveArtboard;
  _RunSimpleAnimation _controllerOn;
  _RunSimpleAnimation _controllerOff;
  _RunSimpleAnimation _controllerUnknown;

  @override
  void initState() {
    currentState = widget.value;
    // Load the animation file from the bundle, note that you could also
    // download this. The RiveFile just expects a list of bytes.
    rootBundle.load(widget.animation).then(
      (data) async {
        final file = RiveFile();

        // Load the RiveFile from the binary data.
        if (file.import(data)) {
          // The artboard is the root of the animation and gets drawn in the
          // Rive widget.
          final artboard = file.mainArtboard;
          // Add a controller to play back a known animation on the main/default
          // artboard.We store a reference to it so we can toggle playback.
          _controllerOn = _RunSimpleAnimation(widget.animationOn);
          _controllerOff = _RunSimpleAnimation(widget.animationOff);
          _controllerUnknown = _RunSimpleAnimation(widget.animationUnknown);
          artboard.addController(_controllerOn);
          artboard.addController(_controllerUnknown);
          artboard.addController(_controllerOff);
          setState(() {
            _riveArtboard = artboard;
            _runAnimation();
          });
        }
      },
    );
    super.initState();
  }

  @override
  void didUpdateWidget(RiveCheckbox oldWidget) {
    if (currentState != widget.value) {
      currentState = widget.value;
      _runAnimation();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _runAnimation() {
    if (currentState == null) {
      _controllerOn.isActive = false;
      _controllerOff.isActive = false;
      _controllerUnknown.isActive = true;
    } else if (currentState) {
      _controllerOff.isActive = false;
      _controllerUnknown.isActive = false;
      _controllerOn.isActive = true;
    } else {
      _controllerOn.isActive = false;
      _controllerUnknown.isActive = false;
      _controllerOff.isActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Rive(
      artboard: _riveArtboard,
      fit: BoxFit.contain,
      useArtboardSize: widget.useArtboardSize,
    );
    if (_riveArtboard == null) {
      child = Container();
    }
    if (widget.width != null || widget.height != null) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      );
    }
    return GestureDetector(
      onTap: widget.onChanged == null
          ? null
          : () {
              if (currentState == null) {
                currentState = true;
              } else {
                currentState = !currentState;
              }
              _runAnimation();
              widget.onChanged(currentState);
            },
      child: child,
    );
  }
}

class _RunSimpleAnimation extends RiveAnimationController<RuntimeArtboard> {
  _RunSimpleAnimation(this.animationName, {double mix}) : _mix = mix?.clamp(0, 1)?.toDouble() ?? 1.0;

  LinearAnimationInstance _instance;
  final String animationName;
  bool _stopOnNextApply = false;

  // Controls the level of mix for the animation, clamped between 0 and 1
  double _mix;

  double get mix => _mix;

  set mix(double value) => _mix = value?.clamp(0, 1)?.toDouble() ?? 1;

  LinearAnimationInstance get instance => _instance;

  @override
  bool init(RuntimeArtboard artboard) {
    var animation = artboard.animations.firstWhere(
      (animation) => animation is LinearAnimation && animation.name == animationName,
      orElse: () => null,
    );
    if (animation != null) {
      _instance = LinearAnimationInstance(animation as LinearAnimation);
    }
    return _instance != null;
  }

  @override
  void apply(RuntimeArtboard artboard, double elapsedSeconds) {
    if (_stopOnNextApply) {
      isActive = false;
    }

    // We apply before advancing. So we want to stop rendering only once the
    // last advanced frame has been applied. This means tracking when the last
    // frame is advanced, ensuring the next apply happens, and then finally
    // stopping playback. We do this by tracking _stopOnNextApply making sure to
    // reset it when the controller is re-activated. Fixes #28 and should help
    // with issues #51 and #56.
    _instance.animation.apply(_instance.time, coreContext: artboard, mix: mix);
    if (!_instance.advance(elapsedSeconds)) {
      _stopOnNextApply = true;
    }
  }

  @override
  void onActivate() {
    // We override onActivate to reset stopOnNextApply. This ensures that when
    // the controller is re-activated after stopping, it doesn't prematurely
    // stop itself.
    _instance.reset();
    _stopOnNextApply = false;
  }
}
