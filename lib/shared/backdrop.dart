// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:responsive_scaffold/responsive_scaffold.dart';

import 'i18n.dart';

const double _kDividerHeadingHeight = 1.0; // front layer divider header height;
const double _kFrontHeadingHeight = 16.0; // front layer circular rectangle
const double _kFrontContainerHeight = 50.0;
const double _kFrontClosedHeight = _kFrontContainerHeight +
    _kDividerHeadingHeight; // front layer height when closed
// const double _kBackAppBarHeight = 56.0; // back layer (options) appbar height

// The size of the front layer heading's left and right beveled corners.
final Animatable<BorderRadius> _kFrontHeadingBevelRadius = BorderRadiusTween(
  begin: const BorderRadius.only(
    topLeft: Radius.circular(_kFrontHeadingHeight),
    topRight: Radius.circular(_kFrontHeadingHeight),
  ),
  end: const BorderRadius.only(
    topLeft: Radius.circular(_kFrontHeadingHeight),
    topRight: Radius.circular(_kFrontHeadingHeight),
  ),
);

class _CrossFadeTransition extends AnimatedWidget {
  const _CrossFadeTransition({
    Key key,
    this.alignment = Alignment.center,
    Animation<double> progress,
    this.child0,
    this.child1,
  }) : super(key: key, listenable: progress);

  final AlignmentGeometry alignment;
  final Widget child0;
  final Widget child1;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = listenable as Animation<double>;

    final double opacity1 = CurvedAnimation(
      parent: ReverseAnimation(progress),
      curve: const Interval(0.5, 1.0),
    ).value;

    final double opacity2 = CurvedAnimation(
      parent: progress,
      curve: const Interval(0.5, 1.0),
    ).value;

    return Stack(
      alignment: alignment,
      children: <Widget>[
        Opacity(
          opacity: opacity1,
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: child1,
          ),
        ),
        Opacity(
          opacity: opacity2,
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: child0,
          ),
        ),
      ],
    );
  }
}

class Backdrop extends StatefulWidget {
  const Backdrop({
    this.floatingActionButton,
    // this.frontAction,
    this.frontTitle,
    this.frontHeadingText,
    this.frontLayer,
    this.backTitle,
    this.backLayer,
    this.drawer,
    this.endDrawer,
  });

  final Widget floatingActionButton;
  // final Widget frontAction;
  final Widget frontTitle;
  final Widget frontLayer;
  final String frontHeadingText;
  final Widget backTitle;
  final Widget backLayer;
  final Widget drawer;
  final Widget endDrawer;

  @override
  _BackdropState createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  final GlobalKey _backdropKey = GlobalKey(debugLabel: 'Backdrop');
  AnimationController _controller;
  Animation<double> _frontOpacity;

  static final Animatable<double> _frontOpacityTween =
      Tween<double>(begin: 0.4, end: 1.0).chain(
          CurveTween(curve: const Interval(0.0, 0.4, curve: Curves.easeInOut)));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      value: 1.0,
      vsync: this,
    );
    _frontOpacity = _controller.drive(_frontOpacityTween);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _backdropHeight {
    // Warning: this can be safely called from the event handlers but it may
    // not be called at build time.
    final RenderBox renderBox =
        _backdropKey.currentContext.findRenderObject() as RenderBox;
    return math.max(0.0, renderBox.size.height - _kFrontClosedHeight);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller.value -=
        details.primaryDelta / (_backdropHeight ?? details.primaryDelta);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_controller.isAnimating ||
        _controller.status == AnimationStatus.completed) return;
    final double flingVelocity =
        details.velocity.pixelsPerSecond.dy / _backdropHeight;
    if (flingVelocity < 0.0)
      _controller.fling(velocity: math.max(2.0, -flingVelocity));
    else if (flingVelocity > 0.0)
      _controller.fling(velocity: math.min(-2.0, -flingVelocity));
    else
      _controller.fling(velocity: _controller.value < 0.5 ? -2.0 : 2.0);
  }

  void _toggleFrontLayer() {
    final AnimationStatus status = _controller.status;
    final bool isOpen = status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
    _controller.fling(velocity: isOpen ? -2.0 : 2.0);
  }

  Widget _buildStack(BuildContext context, BoxConstraints constraints) {
    print('backdrop rebuilt');
    final Animation<RelativeRect> frontRelativeRect =
        _controller.drive(RelativeRectTween(
      begin: RelativeRect.fromLTRB(
          0.0, constraints.biggest.height - _kFrontClosedHeight, 0.0, 0.0),
      end: const RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ));
    return Stack(
      children: <Widget>[
        _TappableWhileStatusIs(
          AnimationStatus.dismissed,
          controller: _controller,
          child: _VisibleWhileStatusIs(
            (status) => status != AnimationStatus.completed,
            controller: _controller,
            child: widget.backLayer,
          ),
        ),
        PositionedTransition(
          rect: frontRelativeRect,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget child) {
              return PhysicalShape(
                elevation: 1.0,
                color: Theme.of(context).canvasColor,
                clipper: ShapeBorderClipper(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        _kFrontHeadingBevelRadius.transform(_controller.value),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleFrontLayer,
                      onVerticalDragUpdate: _handleDragUpdate,
                      onVerticalDragEnd: _handleDragEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        height: _kFrontContainerHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              // height: _kFrontHeadingHeight,
                              child: Text(
                                widget.frontHeadingText,
                                style: Theme.of(context)
                                    .textTheme
                                    .subtitle1
                                    .copyWith(color: Colors.grey),
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleFrontLayer,
                              tooltip: 'Toggle options'.i18n,
                              icon: RotationTransition(
                                turns: Tween(begin: 0.0, end: 0.5)
                                    .animate(_controller),
                                child: Icon(
                                  Icons.expand_less,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: _kDividerHeadingHeight,
                ),
                Expanded(
                  child: _TappableWhileStatusIs(
                    AnimationStatus.completed,
                    controller: _controller,
                    child: FadeTransition(
                      opacity: _frontOpacity,
                      child: widget.frontLayer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // The front "heading" is a (typically transparent) widget that's stacked on
        // top of, and at the top of, the front layer. It adds support for dragging
        // the front layer up and down and for opening and closing the front layer
        // with a tap. It may obscure part of the front layer's topmost child.
      ],
      // Front layer
    );
  }

  @override
  Widget build(BuildContext context) {
    // print(_controller.status);
    return Theme(
      data: Theme.of(context)
          .copyWith(scaffoldBackgroundColor: Theme.of(context).primaryColor),
      child: ResponsiveScaffold(
        // backgroundColor: Theme.of(context).primaryColor,
        scaffoldKey: _backdropKey,
        title: _CrossFadeTransition(
          progress: _controller,
          alignment: AlignmentDirectional.centerStart,
          child0: Semantics(namesRoute: true, child: widget.frontTitle),
          child1: Semantics(namesRoute: true, child: widget.backTitle),
        ),
        menuIcon: Icons.menu,
        // Back layer
        // floatingActionButton:
        //     ScalingButton(widget: widget, controller: _controller),
        drawer: widget.drawer, //todo
        endDrawer: widget.endDrawer,
        appBarElevation: 0,
        floatingActionButton: ScalingButton(
          fab: widget.floatingActionButton,
          controller: _controller,
        ),

        body: LayoutBuilder(builder: _buildStack),
      ),
    );
  }
}

class ScalingButton extends StatefulWidget {
  const ScalingButton({
    Key key,
    @required this.fab,
    @required this.controller,
  }) : super(key: key);

  final Widget fab;
  final AnimationController controller;

  @override
  _ScalingButtonState createState() => _ScalingButtonState();
}

class _ScalingButtonState extends State<ScalingButton> {
  double transformScale = 1.0; // TODO fix
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(updateButtonTransform);
  }

  void updateButtonTransform() {
    // print(transformScale);
    setState(() {
      this.transformScale = widget.controller.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      child: widget.fab,
      scale: transformScale,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(updateButtonTransform);
    super.dispose();
  }
}

class _TappableWhileStatusIs extends StatefulWidget {
  const _TappableWhileStatusIs(
    this.status, {
    Key key,
    this.controller,
    this.child,
  }) : super(key: key);

  final AnimationController controller;
  final AnimationStatus status;
  final Widget child;

  @override
  _TappableWhileStatusIsState createState() => _TappableWhileStatusIsState();
}

class _TappableWhileStatusIsState extends State<_TappableWhileStatusIs> {
  bool _active;

  @override
  void initState() {
    super.initState();
    widget.controller.addStatusListener(_handleStatusChange);
    _active = widget.controller.status == widget.status;
  }

  @override
  void dispose() {
    widget.controller.removeStatusListener(_handleStatusChange);
    super.dispose();
  }

  void _handleStatusChange(AnimationStatus status) {
    final bool value = widget.controller.status == widget.status;
    if (_active != value) {
      setState(() {
        _active = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AbsorbPointer(
      absorbing: !_active,
      child: widget.child,
    );
    // todo reassigning a different child causes a destruction of the old one -> bad
    // if (!_active) {
    //   child = FocusScope(
    //     canRequestFocus: false,
    //     debugLabel: '$_TappableWhileStatusIs',
    //     child: child,
    //   );
    // }
    return child;
  }
}

class _VisibleWhileStatusIs extends StatefulWidget {
  const _VisibleWhileStatusIs(
    this.visible, {
    Key key,
    this.controller,
    this.child,
  }) : super(key: key);

  final AnimationController controller;
  final bool Function(AnimationStatus) visible;
  final Widget child;

  @override
  _VisibleWhileStatusIsState createState() => _VisibleWhileStatusIsState();
}

class _VisibleWhileStatusIsState extends State<_VisibleWhileStatusIs> {
  bool _visible;

  @override
  void initState() {
    super.initState();
    widget.controller.addStatusListener(_handleStatusChange);
    _visible = widget.visible(widget.controller.status);
  }

  @override
  void dispose() {
    widget.controller.removeStatusListener(_handleStatusChange);
    super.dispose();
  }

  void _handleStatusChange(AnimationStatus status) {
    final bool newVisibility = widget.visible(widget.controller.status);
    // print('status change: ${newVisibility ? 'visible' : 'invisible'}');
    if (_visible != newVisibility) {
      setState(() {
        _visible = newVisibility;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      child: widget.child,
      visible: _visible,
      maintainState: true,
      maintainSize: true, // make invisible (still)
      maintainAnimation: true,
    );
  }
}
