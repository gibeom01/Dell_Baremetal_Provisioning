#!/bin/bash

BASE_DIR="./iso"
ORIGINAL_iso="$BASE_DIR/Windows_Server_2019.iso"
CUSTOM_iso="$BASE_DIR/windows_custom.iso"
XML_FILE="$BASE_DIR/autounattend.xml"
WORK_DIR="/tmp/win_custom_build"                    # Mac에서 권한 충돌이 적은 tmp 디렉토리 활용

echo "1. autounattend.xml 파일을 생성합니다..."

# [핵심] UEFI 기반 파티션 (EFI, MSR, Primary) 구조로 변경
cat << 'EOF' > "$XML_FILE"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>100</Size></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format></ModifyPartition>
                        <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
                        <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Letter>C</Letter></ModifyPartition>
                    </ModifyPartitions>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID> 
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>

    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>WinP@ss123!</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <AutoLogon>
                <Password><Value>WinP@ss123!</Value><PlainText>true</PlainText></Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>powershell -Command "Enable-PSRemoting -SkipNetworkProfileCheck -Force"</CommandLine>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
EOF

echo "2. 작업용 디렉토리를 초기화합니다..."
mkdir -p "$WORK_DIR"
rm -rf "$WORK_DIR"/*

echo "3. 원본 iso를 마운트하고 데이터를 복사합니다..."
7z x "$ORIGINAL_iso" -o"$WORK_DIR/"

echo "4. 생성된 autounattend.xml을 삽입합니다..."
cp "$XML_FILE" "$WORK_DIR/autounattend.xml"

# [핵심] UEFI 부팅 시 나오는 "Press any key to boot from CD/DVD..." 대기 프롬프트를 무력화
echo "4.5 부팅 프롬프트(Press any key...) 무력화 바이너리 덮어쓰기..."
if [ -f "$WORK_DIR/efi/microsoft/boot/efisys_noprompt.bin" ]; then
    cp "$WORK_DIR/efi/microsoft/boot/efisys_noprompt.bin" "$WORK_DIR/efi/microsoft/boot/efisys.bin"
fi

echo "5. 커스텀 iso 파일 생성..."
xorriso -as mkisofs \
  -iso-level 4 -J -l -D -N -joliet-long \
  -V "WIN2019_AUTO" \
  -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table \
  -eltorito-alt-boot \
  -e efi/microsoft/boot/efisys.bin -no-emul-boot \
  -udf \
  -o "$CUSTOM_iso" \
  "$WORK_DIR"

echo "작업 완료! 커스텀 iso 파일이 성공적으로 만들어졌습니다."
