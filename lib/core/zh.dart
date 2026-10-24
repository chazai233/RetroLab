import 'film_stocks.dart';

/// Chinese names for the built-in stocks. Brand codes stay recognizable;
/// the line under them is the look, in Chinese.
String stockTitle(FilmStock stock) {
  return _titles[stock.id] ?? stock.name;
}

String stockLook(FilmStock stock) {
  return _looks[stock.id] ?? stock.description;
}

const _titles = <String, String>{
  'kodak_gold_200': '柯达金 200',
  'kodak_ultramax_400': '柯达金 400',
  'portra_400': '肖像 400',
  'kodak_ektar_100': '鲜艳 100',
  'fuji_superia_400': '日常 400',
  'agfa_vista_200': '浓彩 200',
  'fuji_velvia_50': '风光 50',
  'fuji_provia_100f': '自然 100',
  'ilford_hp5': '经典黑白',
  'kodak_tri_x_400': '街拍黑白',
  'ilford_delta_100': '细颗粒黑白',
  'cinestill_800t': '夜灯 800',
  'cinestill_50d': '日光电影',
  'polaroid_600': '拍立得',
  'lomo_400': '交叉冲印',
  'expired_1998': '过期 1998',
  'disposable_flash_800': '一次性闪光',
  'pocket_110': '口袋 110',
  'custom_400_c41': '自定义 400',
};

const _looks = <String, String>{
  'kodak_gold_200': '日光暖调',
  'kodak_ultramax_400': '更暖更艳',
  'portra_400': '肤色柔和',
  'kodak_ektar_100': '细腻鲜红',
  'fuji_superia_400': '偏冷的绿',
  'agfa_vista_200': '红色很冲',
  'fuji_velvia_50': '浓艳反转',
  'fuji_provia_100f': '干净中性',
  'ilford_hp5': '阴影透一点',
  'kodak_tri_x_400': '对比强',
  'ilford_delta_100': '干净细腻',
  'cinestill_800t': '霓虹夜景',
  'cinestill_50d': '日光卤光',
  'polaroid_600': '黑位被抬起',
  'lomo_400': '暗角很重',
  'expired_1998': '偏品红发灰',
  'disposable_flash_800': '直闪硬光',
  'pocket_110': '颗粒很粗',
  'custom_400_c41': '标准彩色负片',
};
