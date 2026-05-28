## Ansible 자동화 파이프라인 실행 방법

###### 1. cd /Users/gibeom/Desktop/Dell_Baremetal_Provisioning/ansible (작업 디렉토리 이동)
###### 2. ansible-playbook -i inventory.ini main_orchestrator.yml --forks 10 (--forks 10 Ansible이 동시에 작업할 최대 노드 개수 -> 서버가 3대라면 3, 10대라면 10 입력 후 진행)

---

## 문법 검증 방법 -> 하드웨어 세팅 단계(Stage 1~2) --syntax-check로 문법만 확인한 뒤, 서비스가 올라간 OS 환경설정(Stage 3~4) 유지보수할 때는 --check --diff 적극적으로 활용

###### 1. 문법 검증 (Syntax Check) -> ansible-playbook linux_config.yml --syntax-check -i inventory.ini
###### 2. 가상 실행 (Dry-run / Check Mode) -> ansible-playbook linux_config.yml --check -i inventory.ini
###### 3. 변경점 상세 비교 (Diff Mode) -> ansible-playbook linux_config.yml --check --diff -i inventory.ini

---

## 특정 태그만 실행 -> 네트워크 정책이 변경되어 전체 Linux 서버의 DNS와 Gateway IP(Netplan/nmcli)만 다시 세팅해야 할 경우 사용.

###### ansible-playbook -i inventory.ini linux_config.yml -e "@group_vars/all.yml" --tags "network"

### 예시)
1. 보안 취약점 조치로 전체 Windows 서버에 긴급 패치(Update)만 돌려야 할 때:
###### ansible-playbook -i inventory.ini windows_config.yml -e "@group_vars/all.yml" --tags "update"
2. RDP 포트와 방화벽 설정만 핀셋으로 변경하고 즉시 적용(재부팅)하고 싶을 때:
###### ansible-playbook -i inventory.ini windows_config.yml -e "@group_vars/all.yml" --tags "rdp,firewall,reboot"
3. 시간이나 대역폭 문제로 무거운 Windows Update 단계만 빼고 빠르게 프로비저닝할 때:
###### ansible-playbook -i inventory.ini windows_config.yml -e "@group_vars/all.yml" --skip-tags "update"

---

## Troubleshooting

### 증상 1: ansible-playbook 명령을 치자마자 에러가 나며 멈춤
###### -> 확인 지점: Syntax Error이거나 YAML 들여쓰기 문제일 확률이 99%
###### -> 조치 방법: 에러 메시지에서 알려주는 line number 확인. (띄어쓰기 2칸 규칙이 어긋났는지, {{ }} 괄호가 제대로 닫혔는지 확인)

### 증상 2: 펌웨어 업데이트나 RAID 구성 단계(Stage 2)에서 멈추거나 실패함 (Mac과 Dell iDRAC 관리망(169.254.x.x) 간의 통신이 안 되거나, RACADM 명령어가 겉도는 경우)
###### -> 확인 지점: ```bash
cat ../logs/idc-node-01_01_firmware.log
cat ../logs/idc-node-01_02_raid.log
###### -> 조치 방법: Mac 터미널에서 ping 169.254.0.3, DRAC 웹 콘솔 로그인 계정/비번(root/calvin)이 맞는지, iDRAC 라이센스(Enterprise 이상 권장)가 만료되지 않았는지 점검, configure_raid.yml 에러면 레이드 꼬여 Foreign Clear 상태일 때 iDRAC 웹 콘솔 스토리지 한 번 수동 날리기

### 증상 3: 가상 CD(ISO) 마운트가 안 되거나, OS 설치 화면으로 넘어가지 않음 (121.125.69.250의 방화벽 막혀 iDRAC ISO 파일 가져오지 못하거나, 스크립트 생성한 ISO 파일 자체 깨진 경우)
###### -> 확인 지점: cat ../logs/idc-node-01_03_deploy.log
###### -> 조치 방법: iDRAC 웹 콘솔 상단의 Virtual Media에서 iso 마운트 확인, Mac 터미널 curl http://121.125.69.250/iso/rocky_custom.iso 쳐서 파일 정상적으로 다운로드되는 상태인지 확인, Mac 시스템 설정 -> 네트워크 -> 방화벽 off 확인.

### 증상 4: OS 설치는 다 끝났는데, 사후 환경 설정(Stage 4)으로 넘어가지 않고 계속 대기(wait_for_connection)하다가 실패함 (Kickstart, Autoinstall 과정에서 121.125.69.252, 서브넷 설정 잘못 들어갔거나, 리눅스 / 윈도우 서비스가올라오지 않은 경우.
###### -> 확인 지점: 터미널 창의 Ansible 빨간색 에러 메시지 확인
###### -> 조치 방법: KVM 화면 띄어 로그인 프롬프트 떠 있는지 부팅 확인, Mac 터미널에서 ping 121.125.69.252, 통신이 안 된다면 .sh 파일들의 IP/GW/DNS 파라미터 현재 테스트 중인 네트워크 스위치 환경 일치하는지 검증.
