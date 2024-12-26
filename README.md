**中文** | [English](README_EN.md)

# KernelSU Action

用于 Non-GKI Kernel 的 Action，具有一定的普遍性，需要了解内核及 Android 的相关知识得以运用。

## 警告 :warning: :warning: :warning:

如果你不是内核作者，使用他人的劳动成果构建 KernelSU，请仅供自己使用，不要分享给别人，这是对原作者的劳动成果的尊重。

## 支持内核

- `5.4`
- `4.19`
- `4.14`
- `4.9`

## 使用

> 所有 config.env 内的变量均只判断`true`

> 编译成功后，会在`Action`上传 AnyKernel3，已经关闭设备检查，请在 Twrp 刷入。

Fork 本仓库到你的储存库然后按照以下内容编辑 config.env，之后点击`Star`或`Action`，在左侧可看见`Build Kernel`选项，点击选项会看见右边的大对话框的上面会有`Run workflows`点击它会启动构建。

### Kernel Source

修改为你的内核仓库地址

例如: https://github.com/Diva-Room/Miku_kernel_xiaomi_wayne

### Kernel Source Branch

修改为你的内核分支

例如: TDA

### Kernel Config

修改为你的内核配置文件名

例如: vendor/wayne_defconfig

### Arch

例如: arm64

### Kernel Image Name

修改为需要刷写的 kernel binary，一般与你的 aosp-device tree 里的 BOARD_KERNEL_IMAGE_NAME 是一致的

例如: Image.gz-dtb

常见还有 Image、Image.gz

### Clang

#### Use custom clang

可以使用除 google 官方的 clang，如[proton-clang](https://github.com/kdrag0n/proton-clang)

#### Custom Clang Source

> 如果是 git 仓库，请填写包含`.git`的链接

支持 git 仓库或者 zip 压缩包的直链

#### Custom cmds

都用自定义 clang 了，自己改改这些配置应该都会吧 :)

#### Clang Branch

由于 [#23](https://github.com/xiaoleGun/KernelSU_Action/issues/23) 的需要，我们提供可自定义 Google 上游分支的选项，主要的有分支有
| Clang 分支 |
| ---------- |
| master |
| master-kernel-build-2021 |
| master-kernel-build-2022 |

或者其它分支，请根据自己的需求在 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 中寻找

#### Clang version

填写需要使用的 Clang 版本
| Clang 版本 | 对应 Android 版本 | AOSP-Clang 版本 |
| ---------- | ----------------- | --------------- |
| 12.0.5 | Android S | r416183b |
| 14.0.6 | Android T | r450784d |
| 14.0.7 |               | r450784e |
| 15.0.1 |               | r458507 |
| 17.0.1 |               | r487747b |
| 17.0.2 | Android U | r487747c |


一般 Clang12 就能通过大部分 4.14 及以上的内核的编译
我自己的 MI 6X 4.19 使用的是 r450784d

### GCC

#### Enable GCC 64

启用 GCC 64 交叉编译

#### Enable GCC 32

启用 GCC 32 交叉编译

### Extra cmds

有的内核需要加入一些其它编译命令，才能正常编译，一般不需要其它的命令，请自行搜索自己内核的资料
请在命令与命令之间用空格隔开

例如: LLVM=1 LLVM_IAS=1

### Enable KernelSU

启用 KernelSU，用于排查内核故障或单独编译内核

#### KernelSU Branch or Tag

[KernelSU 1.0 已经不再支持非 GKI 内核](https://github.com/tiann/KernelSU/issues/1705)，最后的支持版本为 [v0.9.5](https://github.com/tiann/KernelSU/tree/v0.9.5)，请注意使用正确的分支

选择 KernelSU 的分支或 tag:

- ~~main 分支(开发版): `KERNELSU_TAG=main`~~
- 最新 TAG(稳定版): `KERNELSU_TAG=v0.9.5`
- 指定 TAG(如`v0.5.2`): `KERNELSU_TAG=v0.5.2`

#### KernelSU Manager signature size and hash

自定义KernelSU管理器签名的size值和hash值，如果不需要自定义管理器则请留空或填入官方默认值：

`KSU_EXPECTED_SIZE=0x033b`

`KSU_EXPECTED_HASH=c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6`

可键入`ksud debug get-sign <apk_path>`获取apk签名的size值和hash值

### Disable LTO

LTO 用于优化内核，但有些时候会导致错误

### Disable CC_WERROR

用于修复某些不支持或关闭了Kprobes的内核，修复KernelSU未检测到开启Kprobes的变量抛出警告导致错误

### Add Kprobes Config

自动在 defconfig 注入参数

### Add overlayfs Config

此参数为 KernelSU 模块和 system 分区读写提供支持
自动在 defconfig 注入参数

### Apply KernelSU Patch

如果 kprobe 工作不正常（通常是上游的 bug 或者内核版本过低），那你可以尝试启用此参数

自动修改内核源码以支持 KernelSU  
参见：[如何为非GKI设备集成 KernelSU](https://kernelsu.org/zh_CN/guide/how-to-integrate-for-non-gki.html#modify-kernel-source-code)

### Remove unused packages

清理无用的包，以获得更大的磁盘空间

如果你需要这些包，请关闭此项

### AnyKernel3

#### Use custom AnyKernel3

可以使用自定义的 AnyKernel3

#### Custom AnyKernel3 Source

> 如果是 git 仓库，请填写包含`.git`的链接

支持 git 仓库或者 zip 压缩包的直链

#### AnyKernel3 Branch

自定义 AnyKernel3 的仓库分支

### Enable ccache

启用缓存，让第二次编译内核更快，最少可以减少 2/5 的时间

### Need DTBO

上传 DTBO
部分设备需要

### Build Boot IMG

> 从之前的 Workflows 合并进来的，可以查看历史提交

编译 boot.img，需要你提供`Source boot image`

### Source Boot Image

故名思义，提供一个源系统可以正常开机的 boot 镜像，需要直链，最好是同一套内核源码以及与你当前系统同一套设备树从 aosp 构建出来的。ramdisk 里面包含分区表以及 init，没有的话构建出来的镜像会无法正常引导。

例如: https://raw.githubusercontent.com/xiaoleGun/KernelSU_action/main/boot/boot-wayne-from-Miku-UI-latest.img

## 感谢

- [AnyKernel3](https://github.com/osm0sis/AnyKernel3)
- [AOSP](https://android.googlesource.com)
- [KernelSU](https://github.com/tiann/KernelSU)
- [xiaoxindada](https://github.com/xiaoxindada)
- [TheWildJames/kernel_build_scripts](https://github.com/TheWildJames/kernel_build_scripts)
