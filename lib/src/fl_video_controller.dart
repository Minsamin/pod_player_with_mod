import 'dart:async';
import 'dart:developer';

import 'package:fl_video_player/src/fl_enums.dart';
import 'package:fl_video_player/src/vimeo_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import 'vimeo_video_api.dart';

class FlVideoController extends GetxController {
  ///main video controller
  VideoPlayerController? videoCtr;

  ///
  late FlVideoPlayerType videoPlayerType;

  late AnimationController playPauseCtr;

  ///
  FlVideoState flVideoState = FlVideoState.loading;
  bool overlayVisible = true;
  bool autoPlay = true;
  bool isLooping = false;
  bool isFullScreen = false;

  ///
  Duration videoDuration = Duration.zero;
  Duration videoPosition = Duration.zero;

  ///
  late String playingVideoUrl;
  int? vimeoPlayingVideoQuality;

  ///vimeo all quality urls
  List<VimeoVideoQalityUrls>? vimeoVideoUrls;
  List<String> videoPlaybackSpeeds = [
    '0.25x',
    '0.5x',
    '0.75x',
    'Normal',
    '1.25x',
    '1.5x',
    '1.75x',
    '2x',
  ];
  String currentPaybackSpeed = 'Normal';

  //double tap
  Timer? leftDoubleTapTimer;
  Timer? rightDoubleTapTimer;
  int leftDoubleTapduration = 0;
  int rightDubleTapduration = 0;
  bool isLeftDbTapIconVisible = false;
  bool isRightDbTapIconVisible = false;

  ///
  bool _isvideoPlaying = false;
  Timer? hoverOverlayTimer;
  Timer? showOverlayTimer;

  ///**initialize

  void setVideoPlayBack(String _speed) {
    late double pickedSpeed;

    if (_speed == 'Normal') {
      pickedSpeed = 1.0;
      currentPaybackSpeed = 'Normal';
    } else {
      pickedSpeed = double.parse(_speed.split('x').first);
      currentPaybackSpeed = _speed;
    }
    videoCtr?.setPlaybackSpeed(pickedSpeed);
  }

  Future<void> setLooping(bool _isLooped) async {
    isLooping = _isLooped;
    await videoCtr?.setLooping(isLooping);
  }

  Future<void> toggleLooping() async {
    isLooping = !isLooping;
    await videoCtr?.setLooping(isLooping);
  }

  void enableFullScreen() {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    isFullScreen = true;
  }

  Future<void> disableFullScreen() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    isFullScreen = false;
  }

  Future<void> videoInit({
    String? videoUrl,
    String? vimeoVideoId,
    bool isLooping = false,
    int? vimeoVideoQuality,
  }) async {
    checkPlayerType(videoUrl: videoUrl, vimeoVideoId: vimeoVideoId);
    try {
      if (videoPlayerType == FlVideoPlayerType.vimeo) {
        await vimeoPlayerInit(
          vimeoVideoId!,
          vimeoVideoQuality,
        );
      } else {
        playingVideoUrl = videoUrl!;
      }
      videoCtr = VideoPlayerController.network(playingVideoUrl);
      await videoCtr?.initialize();
      videoDuration = videoCtr?.value.duration ?? Duration.zero;
      await setLooping(isLooping);
      videoCtr?.addListener(videoListner);
      update();
    } catch (e) {
      log('cathed $e');
      rethrow;
    }
  }

  Future<void> changeVideoQuality(int? quality) async {
    playingVideoUrl = vimeoVideoUrls
            ?.where((element) => element.quality == quality)
            .first
            .urls ??
        playingVideoUrl;
    log(playingVideoUrl);
    vimeoPlayingVideoQuality = quality;
    videoCtr?.removeListener(videoListner);
    flVideoStateChanger(FlVideoState.paused);
    flVideoStateChanger(FlVideoState.loading);
    videoCtr = VideoPlayerController.network(playingVideoUrl);
    await videoCtr?.initialize();
    videoCtr?.addListener(videoListner);
    await videoCtr?.seekTo(videoPosition);
    setVideoPlayBack(currentPaybackSpeed);
    flVideoStateChanger(FlVideoState.playing);
    update();
  }

  Future<void> videoListner() async {
    if (!videoCtr!.value.isInitialized) {
      await videoCtr!.initialize();
    }
    if (videoCtr!.value.isInitialized) {
      _listneVideoState();
      updateVideoPosition();
    }
  }

  void _listneVideoState() {
    flVideoStateChanger(
      videoCtr!.value.isBuffering || !videoCtr!.value.isInitialized
          ? FlVideoState.loading
          : videoCtr!.value.isPlaying
              ? FlVideoState.playing
              : FlVideoState.paused,
    );
  }

  ///this func will listne to update id `flVideoState`
  void flStateListner() {
    log(flVideoState.toString());
    switch (flVideoState) {
      case FlVideoState.playing:
        playVideo(true);
        break;
      case FlVideoState.paused:
        playVideo(false);
        break;
      case FlVideoState.loading:
        isShowOverlay(true);
        break;
      default:
    }
  }

  ///*seek video
  /// Seek video to a duration.
  Future<void> seekTo(Duration moment) async {
    await videoCtr!.seekTo(moment);
  }

  /// Seek video forward by the duration.
  Future<void> seekForward(Duration videoSeekDuration) async {
    await seekTo(videoCtr!.value.position + videoSeekDuration);
  }

  /// Seek video backward by the duration.
  Future<void> seekBackward(Duration videoSeekDuration) async {
    await seekTo(videoCtr!.value.position - videoSeekDuration);
  }

  ///*controll play pause
  Future<void> playVideo(bool val) async {
    _isvideoPlaying = val;
    if (_isvideoPlaying) {
      isShowOverlay(true);
      // ignore: unawaited_futures
      videoCtr?.play();
      await playPauseCtr.forward();
      isShowOverlay(false, delay: const Duration(seconds: 1));
    } else {
      isShowOverlay(true);
      // ignore: unawaited_futures
      videoCtr?.pause();
      await playPauseCtr.reverse();
    }
  }

  ///toogle play pause
  void togglePlayPauseVideo() {
    _isvideoPlaying = !_isvideoPlaying;
    flVideoStateChanger(
        _isvideoPlaying ? FlVideoState.playing : FlVideoState.paused);
  }

  ///*handle double tap
  void onLeftDoubleTap() {
    isShowOverlay(true);
    leftDoubleTapTimer?.cancel();
    isLeftDbTapIconVisible = true;
    updateLeftTapDuration(leftDoubleTapduration += 10);
    seekBackward(Duration(seconds: leftDoubleTapduration));
    leftDoubleTapTimer = Timer(const Duration(milliseconds: 1500), () {
      isLeftDbTapIconVisible = false;
      updateLeftTapDuration(0);
      leftDoubleTapTimer?.cancel();
      isShowOverlay(false);
    });
  }

  void onRightDoubleTap() {
    isShowOverlay(true);
    rightDoubleTapTimer?.cancel();
    isRightDbTapIconVisible = true;
    updateRightTapDuration(rightDubleTapduration += 10);
    seekForward(Duration(seconds: rightDubleTapduration));
    rightDoubleTapTimer = Timer(const Duration(milliseconds: 1500), () {
      isRightDbTapIconVisible = false;
      updateRightTapDuration(0);
      rightDoubleTapTimer?.cancel();
      isShowOverlay(false);
    });
  }

  ///update doubletap durations
  void updateLeftTapDuration(int val) {
    leftDoubleTapduration = val;
    update(['double-tap']);
  }

  void updateRightTapDuration(int val) {
    rightDubleTapduration = val;
    update(['double-tap']);
  }

  ///*vimeo player configs
  ///
  ///get all  `quality urls`
  Future<void> getVimeoVideoUrls({required String videoId}) async {
    try {
      flVideoStateChanger(FlVideoState.loading);
      final _vimeoVideoUrls = await VimeoVideoApi.getvideoQualityLink(videoId);
      //sort
      _vimeoVideoUrls?.sort((a, b) => a.quality.compareTo(b.quality));

      ///
      vimeoVideoUrls = _vimeoVideoUrls;
    } catch (e) {
      flVideoStateChanger(FlVideoState.error);

      rethrow;
    }
  }

  ///get vimeo quality `ex: 1080p` url
  String? getQualityUrl(int quality) {
    return vimeoVideoUrls
        ?.firstWhere((element) => element.quality == quality)
        .urls;
  }

  ///config vimeo player
  Future<void> vimeoPlayerInit(String videoId, int? quality) async {
    await getVimeoVideoUrls(videoId: videoId);
    final q = quality ?? vimeoVideoUrls?[1].quality ?? 720;
    playingVideoUrl = getQualityUrl(q).toString();
    vimeoPlayingVideoQuality = q;
  }

  ///*General
  ///
  ///clacculates video `position` or `duration`
  String calculateVideoDuration(Duration _duration) {
    final _totalHour = _duration.inHours == 0 ? '' : '${_duration.inHours}:';
    final _totalMinute = _duration.inMinutes.toString();
    final _totalSeconds = (_duration - Duration(minutes: _duration.inMinutes))
        .inSeconds
        .toString()
        .padLeft(2, '0');
    final String videoLength = '$_totalHour$_totalMinute:$_totalSeconds';
    return videoLength;
  }

  void updateVideoPosition() {
    if (videoPosition.inSeconds !=
        (videoCtr?.value.position ?? Duration.zero).inSeconds) {
      videoPosition = videoCtr?.value.position ?? Duration.zero;
      update(['video-progress']);
    }
  }

  ///checkes wether video should be `autoplayed` initially
  void checkAutoPlayVideo() {
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
      if (autoPlay) {
        if (kIsWeb) await videoCtr?.setVolume(0);
        flVideoStateChanger(FlVideoState.playing);
      } else {
        flVideoStateChanger(FlVideoState.paused);
      }
    });
  }

  ///toogle video player controls
  void isShowOverlay(bool val, {Duration? delay}) {
    showOverlayTimer?.cancel();
    showOverlayTimer = Timer(delay ?? Duration.zero, () {
      overlayVisible = val;
      update(['overlay']);
      showOverlayTimer?.cancel();
    });
  }

  void onOverlayHover() {
    if (kIsWeb) {
      hoverOverlayTimer?.cancel();
      isShowOverlay(true);
      hoverOverlayTimer = Timer(
        const Duration(seconds: 4),
        () => isShowOverlay(false),
      );
    }
  }

  void onOverlayHoverExit() {
    if (kIsWeb) {
      isShowOverlay(false);
    }
  }

  ///overlay above video contrller
  Future<void> toggleVideoOverlay() async {
    if (!overlayVisible) {
      overlayVisible = true;
    } else {
      overlayVisible = false;
    }
    update(['overlay']);

    if (overlayVisible) {
      showOverlayTimer?.cancel();
      showOverlayTimer = Timer(const Duration(seconds: 4), () {
        if (overlayVisible) overlayVisible = false;
        update(['overlay']);
        showOverlayTimer?.cancel();
      });
      return;
    }
  }

  ///updates state with id `flVideoState`
  void flVideoStateChanger(FlVideoState? _val) {
    if (flVideoState != (_val ?? flVideoState)) {
      flVideoState = _val ?? flVideoState;
      update(['flVideoState']);
    }
  }

  ///check video player type
  void checkPlayerType({String? vimeoVideoId, String? videoUrl}) {
    if (vimeoVideoId != null) {
      videoPlayerType = FlVideoPlayerType.vimeo;
      return;
    } else {
      if (videoUrl == null) {
        throw Exception('videoUrl is required');
      }
      videoPlayerType = FlVideoPlayerType.general;
    }
  }
}
