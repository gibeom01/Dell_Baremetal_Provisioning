#!/bin/bash

# 사용법: ./make_linux_iso.sh [rocky|centos|ubuntu|ubuntu_legacy|centos_legacy]"
OS_TYPE=$1
BASE_DIR="../iso"
WORK_DIR="/tmp/linux_custom_build"

# ==============================================================================
# 🔥 [네트워크 설정 변수]
# ==============================================================================
MAC_IP="121.125.69.250"                 # Mac(Nginx)의 사무실 IP (어댑터 B에 넣은 IP)    
SRV_IP="121.125.69.252"                 # 서버가 설치 중에 사용할 임시 고정 IP 
SRV_GW="121.125.69.225"                 # 사무실 게이트웨이
SRV_NM="255.255.255.224"                # 사무실 서브넷 마스크 (/27)
SRV_DNS="210.220.163.82,168.126.63.1"   # 사무실 DNS

# [핵심] 스위치 포트 딜레이를 기다려주는 타임아웃 옵션 추가
TIMEOUT_PARAM="inst.ks.timeout=60 rd.net.timeout.carrier=60"
RHEL_IP_PARAM="ip=${SRV_IP}::${SRV_GW}:${SRV_NM}:linux::none:nameserver=${SRV_DNS}"
UBUNTU_IP_PARAM="ip=${SRV_IP}::${SRV_GW}:${SRV_NM}:ubuntu::off:nameserver=${SRV_DNS}"

RHEL_LEGACY_IP_PARAM="ksdevice=link ip=${SRV_IP} netmask=${SRV_NM} gateway=${SRV_GW} dns=${SRV_DNS}"
UBUNTU_LEGACY_IP_PARAM="interface=auto netcfg/disable_autoconfig=true netcfg/get_ipaddress=${SRV_IP} netcfg/get_netmask=${SRV_NM} netcfg/get_gateway=${SRV_GW} netcfg/get_nameservers=${SRV_DNS}"

if [ -z "$OS_TYPE" ]; then
  echo "사용법: $0 [rocky|centos|ubuntu|ubuntu_legacy|centos_legacy]"
  exit 1
fi

echo "1. 작업용 디렉토리를 초기화합니다..."
mkdir -p "$WORK_DIR"
rm -rf "${WORK_DIR:?}"/*

if [ "$OS_TYPE" == "rocky" ]; then
    echo "=== [Rocky Linux 리패키징 시작] ==="
    ORIGINAL_iso="$BASE_DIR/Rocky-8.10-x86_64-dvd1.iso"
    CUSTOM_iso="$BASE_DIR/rocky_custom.iso"
    
    echo "2. 원본 iso 마운트 및 복사..."
    7z x -y "$ORIGINAL_iso" -o"$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"

    echo "3. 부트로더 수정 (네트워크 타임아웃 대기 및 cdrom 강제 마운트)..."
    sed -i '' "s|inst.stage2=hd:LABEL=[^ ]*|inst.stage2=cdrom ${RHEL_IP_PARAM} ${TIMEOUT_PARAM} inst.ks=http://${MAC_IP}/iso/rocky_ks.cfg|g" "$WORK_DIR/isolinux/isolinux.cfg"
    sed -i '' "s|inst.stage2=hd:LABEL=[^ ]*|inst.stage2=cdrom ${RHEL_IP_PARAM} ${TIMEOUT_PARAM} inst.ks=http://${MAC_IP}/iso/rocky_ks.cfg|g" "$WORK_DIR/EFI/BOOT/grub.cfg"

    # UEFI 부팅 시 'Test media'(인덱스 1) 대신 바로 'Install'(인덱스 0)이 선택되도록 변경
    sed -i '' 's/set default="1"/set default="0"/g' "$WORK_DIR/EFI/BOOT/grub.cfg"
    # 선택 대기 시간(Timeout)을 60초에서 5초로 단축하여 즉시 설치 진입
    sed -i '' 's/set timeout=60/set timeout=5/g' "$WORK_DIR/EFI/BOOT/grub.cfg"

    echo "4. 하이브리드 ISO 생성..."
    xorriso -as mkisofs -r -V "ROCKY8" -J -joliet-long \
      -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
      -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -isohybrid-gpt-basdat \
      -o "$CUSTOM_iso" "$WORK_DIR"

elif [ "$OS_TYPE" == "centos" ]; then
    echo "=== [CentOS 리패키징 시작] ==="
    ORIGINAL_iso="$BASE_DIR/CentOS-8-x86_64-dvd1.iso"
    CUSTOM_iso="$BASE_DIR/centos_custom.iso"
    
    echo "2. 원본 iso 마운트 및 복사..."
    7z x -y "$ORIGINAL_iso" -o"$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"

    echo "3. 부트로더 수정..."
    sed -i '' "s|inst.stage2|${RHEL_IP_PARAM} ${TIMEOUT_PARAM} inst.ks=http://${MAC_IP}/iso/rocky_ks.cfg inst.stage2|g" "$WORK_DIR/isolinux/isolinux.cfg"
    sed -i '' "s|inst.stage2|${RHEL_IP_PARAM} ${TIMEOUT_PARAM} inst.ks=http://${MAC_IP}/iso/rocky_ks.cfg inst.stage2|g" "$WORK_DIR/EFI/BOOT/grub.cfg"

    # UEFI 부팅 시 'Test media'(인덱스 1) 대신 바로 'Install'(인덱스 0)이 선택되도록 변경
    sed -i '' 's/hd:LABEL=[^ ]*/cdrom/g' "$WORK_DIR/isolinux/isolinux.cfg"
    # 선택 대기 시간(Timeout)을 60초에서 5초로 단축하여 즉시 설치 진입
    sed -i '' 's/hd:LABEL=[^ ]*/cdrom/g' "$WORK_DIR/EFI/BOOT/grub.cfg"

    sed -i '' 's/set default="1"/set default="0"/g' "$WORK_DIR/EFI/BOOT/grub.cfg"
    sed -i '' 's/set timeout=60/set timeout=5/g' "$WORK_DIR/EFI/BOOT/grub.cfg"

    echo "4. 하이브리드 ISO 생성..."
    xorriso -as mkisofs -r -V "CentOS-8-x86_64-dvd1" -J -joliet-long \
      -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
      -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -isohybrid-gpt-basdat \
      -o "$CUSTOM_iso" "$WORK_DIR"

elif [ "$OS_TYPE" == "centos_legacy" ]; then
    echo "=== [CentOS 5.11 레거시 리패키징 시작] ==="
    ORIGINAL_iso="$BASE_DIR/CentOS_5.11_x86_64_bin_DVD_1of2.iso"
    CUSTOM_iso="$BASE_DIR/centos_legacy_custom.iso"
    
    echo "2. 원본 iso 마운트 및 복사..."
    7z x -y "$ORIGINAL_iso" -o"$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"

    echo "3. 부트로더 수정..."
    sed -i '' "s|append |append ks=http://${MAC_IP}/iso/rocky_ks.cfg ${RHEL_LEGACY_IP_PARAM} |g" "$WORK_DIR/isolinux/isolinux.cfg"
    
    # 라벨(LABEL) 검사를 피하도록 cdrom 우회 (파일에 LABEL 문자열이 있을 경우를 대비)
    sed -i '' 's/hd:LABEL=[^ ]*/cdrom/g' "$WORK_DIR/isolinux/isolinux.cfg"
    # 대기 시간 60초(600)를 5초(50)로 단축
    sed -i '' 's/timeout 600/timeout 50/g' "$WORK_DIR/isolinux/isolinux.cfg" || true

    echo "4. 레거시 전용 ISO 생성..."
    xorriso -as mkisofs -r -V "CentOS_5.11_x86_64_bin_DVD_1of2" -J -joliet-long \
      -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
      -o "$CUSTOM_iso" "$WORK_DIR"

elif [ "$OS_TYPE" == "ubuntu" ]; then
    echo "=== [Ubuntu Server 리패키징 시작] ==="
    ORIGINAL_iso="$BASE_DIR/Ubuntu-22.04.iso"
    CUSTOM_iso="$BASE_DIR/ubuntu_custom.iso"
    
    echo "2. 원본 iso 마운트 및 복사..."
    7z x -y "$ORIGINAL_iso" -o"$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"

    echo "3. 부트로더 수정 (UEFI grub 및 autoinstall 파라미터 추가)..."
    # Ubuntu 22.04는 'autoinstall' 플래그가 필수입니다. UEFI 부팅을 위해 grub.cfg도 수정합니다.
    sed -i '' "s|---|autoinstall ${UBUNTU_IP_PARAM} ds=nocloud-net;s=http://${MAC_IP}/iso/ ---|g" "$WORK_DIR/isolinux/txt.cfg" || true
    sed -i '' "s|---|autoinstall ${UBUNTU_IP_PARAM} ds=nocloud-net;s=http://${MAC_IP}/iso/ ---|g" "$WORK_DIR/boot/grub/grub.cfg" || true
    
    sed -i '' 's/timeout.*/timeout 10/g' "$WORK_DIR/isolinux/isolinux.cfg" || true
    sed -i '' 's/set timeout=30/set timeout=5/g' "$WORK_DIR/boot/grub/grub.cfg" || true

    echo "4. 하이브리드 ISO 생성..."
    xorriso -as mkisofs -r -V "Ubuntu-22.04" -J -l \
      -b boot/grub/i386-pc/eltorito.img -c boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table \
      -eltorito-alt-boot -e EFI/boot/bootx64.efi -no-emul-boot -isohybrid-gpt-basdat \
      -o "$CUSTOM_iso" "$WORK_DIR"

elif [ "$OS_TYPE" == "ubuntu_legacy" ]; then
    echo "=== [Ubuntu 16/18 Legacy 리패키징 시작] ==="
    ORIGINAL_iso="$BASE_DIR/ubuntu-18.04.6-live-server-amd64.iso"
    CUSTOM_iso="$BASE_DIR/ubuntu_legacy_custom.iso"
    
    echo "2. 원본 iso 마운트 및 복사..."
    7z x -y "$ORIGINAL_iso" -o"$WORK_DIR/"
    chmod -R u+w "$WORK_DIR"

    echo "3. 부트로더 수정..."
    sed -i '' "s|---|url=http://${MAC_IP}/iso/ubuntu_preseed.seed ${UBUNTU_LEGACY_IP_PARAM} auto=true priority=critical ---|g" "$WORK_DIR/isolinux/txt.cfg" || true
    sed -i '' "s|---|url=http://${MAC_IP}/iso/ubuntu_preseed.seed ${UBUNTU_LEGACY_IP_PARAM} auto=true priority=critical ---|g" "$WORK_DIR/boot/grub/grub.cfg" || true
    sed -i '' 's/timeout .*/timeout 10/g' "$WORK_DIR/isolinux/isolinux.cfg" || true

    echo "4. 하이브리드 ISO 생성..."
    xorriso -as mkisofs -r -V "ubuntu-18.04.6-live-server-amd64" -J -l \
      -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
      -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat \
      -o "$CUSTOM_iso" "$WORK_DIR"

else
    echo "🚨 지원하지 않는 OS 타입입니다."
    exit 1
fi

echo "🎉 작업 완료! $CUSTOM_iso 파일이 성공적으로 만들어졌습니다."
