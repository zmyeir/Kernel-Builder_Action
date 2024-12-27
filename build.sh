#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

curl -so repo https://storage.googleapis.com/git-repo-downloads/repo
sudo mv repo /usr/bin
sudo chmod +x /usr/bin/repo

export KBUILD_BUILD_USER=buildbot
export KBUILD_BUILD_HOST=buildhost

# Iterate over configurations
build_config() {
    GKI_VERSION=android14-6.1
    KWORKSPACE=/mnt/kernel_workspace

    # Log file for this build in case of failure
    # LOG_FILE="../${CONFIG}_build.log"

    echo "Starting build ${GKI_VERSION}-lts..."

    # Check if susfs4ksu repo exists, remove it if it does
    if [ -d "./susfs4ksu" ]; then
        echo "Removing existing susfs4ksu directory..."
        rm -rf ./susfs4ksu
    fi
    echo "Cloning susfs4ksu repository..."
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "gki-${GKI_VERSION}"

    mkdir -p "$GKI_VERSION"
    ls -lah .
    pwd
    cd "$GKI_VERSION"
    pwd

    # Initialize and sync kernel source with updated repo commands
    echo "Initializing and syncing kernel source..."
    repo init --depth=1 --u https://android.googlesource.com/kernel/manifest -b common-${GKI_VERSION}-lts
    REMOTE_BRANCH=$(git ls-remote https://android.googlesource.com/kernel/common ${GKI_VERSION}-lts)
    DEFAULT_MANIFEST_PATH=.repo/manifests/default.xml
    
    # Check if the branch is deprecated and adjust the manifest
    if grep -q deprecated <<< $REMOTE_BRANCH; then
        echo "Found deprecated branch: ${GKI_VERSION}-lts"
        sed -i "s/\"${GKI_VERSION}-lts\"/\"deprecated\/${GKI_VERSION}-lts\"/g" $DEFAULT_MANIFEST_PATH
    fi

    # Verify repo version and sync
    repo --version
    repo --trace sync -c -j$(nproc --all) --no-tags --fail-fast

    # Apply KernelSU and SUSFS patches
    echo "Adding KernelSU..."
    wget https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/magic/kernel/setup.sh
    # sed -i 's|tiann/KernelSU|5ec1cff/KernelSU|' setup.sh
    bash setup.sh magic

    echo "Applying SUSFS patches..."
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ${KWORKSPACE}/${GKI_VERSION}/KernelSU/
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/50_add_susfs_in_gki-${GKI_VERSION}.patch ${KWORKSPACE}/${GKI_VERSION}/common/
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/fs/susfs.c ./common/fs/
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/include/linux/susfs.h ${KWORKSPACE}/${GKI_VERSION}/common/include/linux/
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/fs/sus_su.c ./common/fs/
    cp ${KWORKSPACE}/susfs4ksu/kernel_patches/include/linux/sus_su.h ${KWORKSPACE}/${GKI_VERSION}/common/include/linux/

    # Apply the patches
    cd ${KWORKSPACE}/${GKI_VERSION}/KernelSU
    pwd
    patch -p1 < 10_enable_susfs_for_ksu.patch
    cd ${KWORKSPACE}/${GKI_VERSION}/common
    pwd
    patch -p1 < 50_add_susfs_in_gki-${GKI_VERSION}.patch
    cd ${KWORKSPACE}/${GKI_VERSION}

    # Add configuration settings for SUSFS
    echo "Adding configuration settings to gki_defconfig..."
    echo "CONFIG_KSU=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig

    # Add config
    echo "CONFIG_PID_NS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_POSIX_MQUEUE=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_IPC_NS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_USER_NS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_BPF_STREAM_PARSER=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    #echo "CONFIG_BRIDGE_NETFILTER=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    #echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    #echo "CONFIG_NETFILTER_XT_MATCH_IPVS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    #echo "CONFIG_CGROUP_DEVICE=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    #echo "CONFIG_CGROUP_PIDS=y" >> ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig
    cat ${KWORKSPACE}/${GKI_VERSION}/common/arch/arm64/configs/gki_defconfig

    # Build kernel
    echo "Building kernel..."
    echo "Running Bazel build..."
    sed -i '/stable_scmversion_cmd/s/maybe-dirty/Ryhoaca/;s/-$android_release-$KMI_GENERATION/-lts/g' ./build/kernel/kleaf/impl/stamp.bzl
    sed -i '2s/check_defconfig//' ./common/build.config.gki
    rm -rf ./common/android/abi_gki_protected_exports_aarch64
    rm -rf ./common/android/abi_gki_protected_exports_x86_64
    tools/bazel build --config=fast //common:kernel_aarch64_dist
    # Creating Boot imgs
    echo "Creating Image..."
    cp ./bazel-bin/common/kernel_aarch64/Image /mnt/kernel_workspace/

}

# Concurrent build management
build_config


echo "Build process complete."

exit
