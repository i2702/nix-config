// disp-hdr: 外部ディスプレイの HDR を macOS 側から切り替える。
//
//   disp-hdr                 全ディスプレイの UUID と HDR 状態を表示
//   disp-hdr <UUID> on|off   指定ディスプレイの HDR を切り替える
//
// 公開 API に HDR の切り替えが無いため、SkyLight の非公開関数を dlsym で引く。
// リンク時に private framework を指定しないのは、シンボルが消えた macOS で
// 起動すらできなくなるのを避け、実行時のエラーとして報告するため。
#include <ColorSync/ColorSync.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef bool (*is_hdr_fn)(CGDirectDisplayID);
typedef CGError (*set_hdr_fn)(CGDirectDisplayID, bool, int, int);

static void uuid_of(CGDirectDisplayID id, char *buf, size_t len) {
  CFUUIDRef u = CGDisplayCreateUUIDFromDisplayID(id);
  buf[0] = '\0';
  if (!u) return;
  CFStringRef s = CFUUIDCreateString(NULL, u);
  CFStringGetCString(s, buf, (CFIndex)len, kCFStringEncodingUTF8);
  CFRelease(s);
  CFRelease(u);
}

int main(int argc, char **argv) {
  if (argc != 1 && argc != 3) {
    fprintf(stderr, "usage: disp-hdr [<UUID> on|off]\n");
    return 2;
  }
  bool enable = false;
  if (argc == 3) {
    if (strcmp(argv[2], "on") == 0) enable = true;
    else if (strcmp(argv[2], "off") != 0) {
      fprintf(stderr, "disp-hdr: on / off を指定してください: %s\n", argv[2]);
      return 2;
    }
  }

  void *sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
  is_hdr_fn is_hdr = sky ? (is_hdr_fn)dlsym(sky, "SLSDisplayIsHDRModeEnabled") : NULL;
  set_hdr_fn set_hdr = sky ? (set_hdr_fn)dlsym(sky, "SLSDisplaySetHDRModeEnabled") : NULL;
  if (!is_hdr || !set_hdr) {
    fprintf(stderr, "disp-hdr: SkyLight の HDR 関数が見つかりません\n");
    return 1;
  }

  CGDirectDisplayID ids[16];
  uint32_t n = 0;
  CGGetOnlineDisplayList(16, ids, &n);

  char uuid[64];
  for (uint32_t i = 0; i < n; i++) {
    uuid_of(ids[i], uuid, sizeof uuid);
    if (argc == 1) {
      printf("%s %s\n", uuid, is_hdr(ids[i]) ? "on" : "off");
    } else if (strcasecmp(uuid, argv[1]) == 0) {
      CGError err = set_hdr(ids[i], enable, 0, 0);
      if (err != kCGErrorSuccess) {
        fprintf(stderr, "disp-hdr: 切り替えに失敗しました (CGError %d)\n", err);
        return 1;
      }
      return 0;
    }
  }
  if (argc == 3) {
    fprintf(stderr, "disp-hdr: ディスプレイが見つかりません: %s\n", argv[1]);
    return 1;
  }
  return 0;
}
