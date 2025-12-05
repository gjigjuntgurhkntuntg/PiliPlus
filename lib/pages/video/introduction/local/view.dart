import 'dart:io';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/video/introduction/local/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class LocalIntroPanel extends StatefulWidget {
  const LocalIntroPanel({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<LocalIntroPanel> createState() => _LocalIntroPanelState();
}

class _LocalIntroPanelState extends State<LocalIntroPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _controller = Get.find<LocalIntroController>(tag: widget.heroTag);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Obx(() {
      final hasNetwork = _controller.hasNetwork.value;
      final onlineDetailLoaded = _controller.onlineDetailLoaded.value;
      final currIndex = _controller.index.value;

      return SliverList(
        delegate: SliverChildListDelegate([
          // 视频详情区域（有网络时显示）
          if (hasNetwork && onlineDetailLoaded) ...[
            _buildVideoDetailSection(context, theme),
            const SizedBox(height: 8),
            _buildActionButtons(context, theme),
            const Divider(height: 24, indent: 12, endIndent: 12),
          ] else if (hasNetwork && !onlineDetailLoaded) ...[
            // 加载中提示
            const Padding(
              padding: EdgeInsets.all(StyleString.safeSpace),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
          // 离线视频列表
          ..._controller.list.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildItem(theme, currIndex == index, index, item);
          }),
        ]),
      );
    });
  }

  /// 构建视频详情区域
  Widget _buildVideoDetailSection(BuildContext context, ThemeData theme) {
    final videoDetail = _controller.videoDetail.value;
    final owner = videoDetail.owner;
    final userStat = _controller.userStat.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StyleString.safeSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // UP主信息行
          if (owner != null)
            GestureDetector(
              onTap: () {
                feedBack();
                Get.toNamed('/member?mid=${owner.mid}');
              },
              child: Row(
                children: [
                  PendantAvatar(
                    avatar: owner.face ?? '',
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.name ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (userStat.follower != null)
                          Text(
                            '${NumUtils.numFormat(userStat.follower)} 粉丝',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 关注按钮
                  _buildFollowButton(context, theme),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // 视频统计数据
          if (videoDetail.stat != null)
            Row(
              children: [
                StatWidget(
                  value: videoDetail.stat!.view,
                  type: StatType.play,
                ),
                const SizedBox(width: 10),
                StatWidget(
                  value: videoDetail.stat!.danmaku,
                  type: StatType.danmaku,
                ),
                const Spacer(),
                // 同时在看
                Obx(() {
                  if (_controller.isShowOnlineTotal &&
                      _controller.total.value != '1') {
                    return Text(
                      '${_controller.total.value}人在看',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
        ],
      ),
    );
  }

  /// 构建关注按钮
  Widget _buildFollowButton(BuildContext context, ThemeData theme) {
    return Obx(() {
      final followStatus = _controller.followStatus;
      if (followStatus.isEmpty) {
        return const SizedBox.shrink();
      }
      final attribute = followStatus['attribute'] ?? 0;
      final isFollowed = attribute == 2 || attribute == 6 || attribute == -10;

      return FilledButton.tonal(
        onPressed: () async {
          if (!_controller.hasNetwork.value) {
            return;
          }
          // TODO: 实现关注/取消关注功能
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          isFollowed ? '已关注' : '关注',
          style: const TextStyle(fontSize: 13),
        ),
      );
    });
  }

  /// 构建操作按钮区域
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    final videoDetail = _controller.videoDetail.value;
    final isLoading = videoDetail.stat == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StyleString.safeSpace),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 点赞
            Obx(
              () => ActionItem(
                animation: _controller.tripleAnimation,
                icon: const Icon(FontAwesomeIcons.thumbsUp),
                selectIcon: const Icon(FontAwesomeIcons.solidThumbsUp),
                selectStatus: _controller.hasLike.value,
                semanticsLabel: '点赞',
                text: !isLoading
                    ? NumUtils.numFormat(videoDetail.stat!.like)
                    : null,
                onStartTriple: _controller.onStartTriple,
                onCancelTriple: _controller.onCancelTriple,
              ),
            ),
            // 点踩
            Obx(
              () => ActionItem(
                icon: const Icon(FontAwesomeIcons.thumbsDown),
                selectIcon: const Icon(FontAwesomeIcons.solidThumbsDown),
                onTap: () => _controller.handleAction(_actionDislike),
                selectStatus: _controller.hasDislike.value,
                semanticsLabel: '点踩',
                text: '点踩',
              ),
            ),
            // 投币
            Obx(
              () => ActionItem(
                animation: _controller.tripleAnimation,
                icon: const Icon(FontAwesomeIcons.b),
                selectIcon: const Icon(FontAwesomeIcons.b),
                onTap: _controller.actionCoinVideo,
                selectStatus: _controller.hasCoin,
                semanticsLabel: '投币',
                text: !isLoading
                    ? NumUtils.numFormat(videoDetail.stat!.coin)
                    : null,
              ),
            ),
            // 收藏
            Obx(
              () => ActionItem(
                animation: _controller.tripleAnimation,
                icon: const Icon(FontAwesomeIcons.star),
                selectIcon: const Icon(FontAwesomeIcons.solidStar),
                onTap: () => _controller.showFavBottomSheet(context),
                onLongPress: () => _controller.showFavBottomSheet(
                  context,
                  isLongPress: true,
                ),
                selectStatus: _controller.hasFav.value,
                semanticsLabel: '收藏',
                text: !isLoading
                    ? NumUtils.numFormat(videoDetail.stat!.favorite)
                    : null,
              ),
            ),
            // 稍后再看
            Obx(
              () => ActionItem(
                icon: const Icon(FontAwesomeIcons.clock),
                selectIcon: const Icon(FontAwesomeIcons.solidClock),
                onTap: () => _controller.handleAction(_controller.viewLater),
                selectStatus: _controller.hasLater.value,
                semanticsLabel: '再看',
                text: '再看',
              ),
            ),
            // 分享
            ActionItem(
              icon: const Icon(FontAwesomeIcons.shareFromSquare),
              onTap: () => _controller.actionShareVideo(context),
              selectStatus: false,
              semanticsLabel: '分享',
              text: !isLoading
                  ? NumUtils.numFormat(videoDetail.stat!.share ?? 0)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _actionDislike() async {
    await _controller.actionDislikeVideo();
  }

  Widget _buildItem(
    ThemeData theme,
    bool isCurr,
    int index,
    BiliDownloadEntryInfo entry,
  ) {
    final outline = theme.colorScheme.outline;
    final cover = File(path.join(entry.entryDirPath, PathUtils.coverName));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 98,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              if (isCurr) {
                return;
              }
              _controller.playIndex(index, entry: entry);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StyleString.safeSpace,
                vertical: 5,
              ),
              child: Row(
                spacing: 10,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      cover.existsSync()
                          ? ClipRRect(
                              borderRadius: StyleString.mdRadius,
                              child: Image.file(
                                cover,
                                width: 140.8,
                                height: 88,
                                fit: BoxFit.cover,
                                cacheHeight: 140.8.cacheSize(context),
                                colorBlendMode: NetworkImgLayer.reduce
                                    ? BlendMode.modulate
                                    : null,
                                color: NetworkImgLayer.reduce
                                    ? NetworkImgLayer.reduceLuxColor
                                    : null,
                              ),
                            )
                          : NetworkImgLayer(
                              src: entry.cover,
                              width: 140.8,
                              height: 88,
                            ),
                      PBadge(
                        text: DurationUtils.formatDuration(
                          entry.totalTimeMilli ~/ 1000,
                        ),
                        right: 6.0,
                        bottom: 6.0,
                        type: PBadgeType.gray,
                      ),
                      if (entry.videoQuality case final videoQuality?)
                        PBadge(
                          text: VideoQuality.fromCode(videoQuality).shortDesc,
                          right: 6.0,
                          top: 6.0,
                          type: PBadgeType.gray,
                        ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          spacing: 5,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: theme.textTheme.bodyMedium!.fontSize,
                                height: 1.42,
                                letterSpacing: 0.3,
                                color: isCurr
                                    ? theme.colorScheme.primary
                                    : null,
                                fontWeight: isCurr ? FontWeight.bold : null,
                              ),
                              maxLines: entry.ep != null ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (entry.pageData?.part case final part?)
                              if (part != entry.title)
                                Text(
                                  part,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            if (entry.ep?.showTitle case final showTitle?)
                              Text(
                                showTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (entry.ownerName case final ownerName?)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              ownerName,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1,
                                color: outline,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: entry.moreBtn(theme),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
