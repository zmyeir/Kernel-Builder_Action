#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

#DO NOT GO OVER 4
#MAX_CONCURRENT_BUILDS=1

# Check if 'builds' folder exists, create it if not
if [ ! -d "./builds" ]; then
    echo "'builds' folder not found. Creating it..."
    mkdir -p ./builds
else
    echo "'builds' folder already exists removing it."
    rm -rf ./builds
    mkdir -p ./builds
fi

cd ./builds

# Iterate over configurations
build_config() {
    CONFIG=$1
    CONFIG_DETAILS=${CONFIG}

    # Create a directory named after the current configuration
    echo "Creating folder for configuration: $CONFIG..."
    mkdir -p "$CONFIG"
    cd "$CONFIG"
    
    # Split the config details into individual components
    IFS="-" read -r ANDROID_VERSION KERNEL_VERSION SUB_LEVEL DATE <<< "$CONFIG_DETAILS"
    
    # Formatted branch name for each build (e.g., android14-5.15-2024-01)
    FORMATTED_BRANCH="${ANDROID_VERSION}-${KERNEL_VERSION}-${DATE}"

    # Log file for this build in case of failure
    LOG_FILE="../${CONFIG}_build.log"

    echo "Starting build for $CONFIG using branch $FORMATTED_BRANCH..."
    # Check if AnyKernel3 repo exists, remove it if it does
    if [ -d "./AnyKernel3" ]; then
        echo "Removing existing AnyKernel3 directory..."
        rm -rf ./AnyKernel3
    fi
    echo "Cloning AnyKernel3 repository..."
    git clone https://github.com/TheRyhoacaJames/AnyKernel3.git -b "${ANDROID_VERSION}-${KERNEL_VERSION}"

    # Check if susfs4ksu repo exists, remove it if it does
    if [ -d "./susfs4ksu" ]; then
        echo "Removing existing susfs4ksu directory..."
        rm -rf ./susfs4ksu
    fi
    echo "Cloning susfs4ksu repository..."
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "gki-${ANDROID_VERSION}-${KERNEL_VERSION}"

    mkdir -p "$CONFIG"
    ls -lah .
    pwd
    cd "$CONFIG"
    pwd

    # Initialize and sync kernel source with updated repo commands
    echo "Initializing and syncing kernel source..."
    repo init --depth=1 --u https://android.googlesource.com/kernel/manifest -b common-${FORMATTED_BRANCH}
    REMOTE_BRANCH=$(git ls-remote https://android.googlesource.com/kernel/common ${FORMATTED_BRANCH})
    DEFAULT_MANIFEST_PATH=.repo/manifests/default.xml
    
    # Check if the branch is deprecated and adjust the manifest
    if grep -q deprecated <<< $REMOTE_BRANCH; then
        echo "Found deprecated branch: $FORMATTED_BRANCH"
        sed -i "s/\"${FORMATTED_BRANCH}\"/\"deprecated\/${FORMATTED_BRANCH}\"/g" $DEFAULT_MANIFEST_PATH
    fi

    # Verify repo version and sync
    repo --version
    repo --trace sync -c -j$(nproc --all) --no-tags --fail-fast

    # Apply KernelSU and SUSFS patches
    echo "Adding KernelSU..."
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

    echo "Applying SUSFS patches..."
    cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
    cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch ./common/
    cp ../susfs4ksu/kernel_patches/fs/susfs.c ./common/fs/
    cp ../susfs4ksu/kernel_patches/include/linux/susfs.h ./common/include/linux/
    cp ../susfs4ksu/kernel_patches/fs/sus_su.c ./common/fs/
    cp ../susfs4ksu/kernel_patches/include/linux/sus_su.h ./common/include/linux/

    # Apply the patches
    cd ./KernelSU
    patch -p1 < 10_enable_susfs_for_ksu.patch
    cd ../common
    patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch
    cd ..

    # Add configuration settings for SUSFS
    echo "Adding configuration settings to gki_defconfig..."
    echo "CONFIG_KSU=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> ./common/arch/arm64/configs/gki_defconfig
    echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> ./common/arch/arm64/configs/gki_defconfig



    # Build kernel
    echo "Building kernel for $CONFIG..."

    # Check if build.sh exists, if it does, run the default build script
    if [ -e build/build.sh ]; then
        echo "build.sh found, running default build script..."
        # Modify config files for the default build process
        sed -i '2s/check_defconfig//' ./common/build.config.gki
        sed -i "s/dirty/'Ryhoaca+'/g" ./common/scripts/setlocalversion
        LTO=thin BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
    
        # Check if the boot.img file exists
        if [ "$ANDROID_VERSION" = "android12" ]; then
            mkdir bootimgs
            cp ./out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist/Image /mnt/kernel_workspace

        elif [ "$ANDROID_VERSION" = "android13" ]; then
            cp ./out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist/Image /mnt/kernel_workspace
        fi
    else
        # Use Bazel build if build.sh exists
        echo "Running Bazel build..."
        sed -i "/stable_scmversion_cmd/s/-maybe-dirty/-Ryhoaca+/g" ./build/kernel/kleaf/impl/stamp.bzl
        sed -i '2s/check_defconfig//' ./common/build.config.gki
        rm -rf ./common/android/abi_gki_protected_exports_aarch64
        rm -rf ./common/android/abi_gki_protected_exports_x86_64
        tools/bazel build --config=fast //common:kernel_aarch64_dist
        

        # Creating Boot imgs
        echo "Creating boot.imgs..."
        if [ "$ANDROID_VERSION" = "android14" ]; then
            cp ./bazel-bin/common/kernel_aarch64/Image /mnt/kernel_workspace/
        fi
    fi

}

# Concurrent build management
build_config "android14-6.1-112-2024-11" 


echo "Build process complete."

exit
