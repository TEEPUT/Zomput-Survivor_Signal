# Zomput-Survivor_Signal

By **TEEPUT**, for Project Zomboid **42.21** dedicated multiplayer servers.

생존자에게 핸드폰을 한 대 지급합니다. 핸드폰 우클릭 → **생존자 위치 조회**로 게임 날짜마다 1회 사용합니다. 게임 시간 00:00에 사용 제한이 초기화됩니다.

- 정상 핸드폰을 휴대한 다른 접속자의 조회 시점 좌표(X/Y/Z)를 팝업과 미니맵에 표시합니다. 가방 안의 핸드폰도 포함합니다.
- 기본 내구도는 100이며 조회당 3포인트 감소합니다. 샌드박스 **생존자 신호 → 조회당 핸드폰 내구도 감소율**에서 정수 0~100을 설정합니다.
- 검색 결과가 없어도 사용 횟수와 내구도를 소모합니다. 남은 내구도가 소모량보다 적어도 마지막 조회는 성공하고 0이 됩니다.
- 0 내구도, 바닥·차량 보관, 사망·접속 종료·투명 관리자 캐릭터는 새 조회 대상에서 제외됩니다.
- 지도 표시는 실시간 추적이 아닙니다. 조회 이후 대상의 이동·사망은 기존 기록을 변경하지 않습니다. 자정, 조회자의 사망 또는 정상 핸드폰 미소지 시 기록을 지웁니다.
- 재접속·새 핸드폰·부활로 계정별 당일 제한을 우회할 수 없습니다. 팝업과 좌표 기록은 클라이언트 메모리에만 있으므로 재접속 후 복원되지 않습니다.
- 기존 캐릭터는 모드를 처음 적용한 후 1대, 새 캐릭터는 새로 1대를 받습니다. 버리거나 잃어버린 핸드폰은 자동 재지급하지 않습니다.
- 배터리·수리·제작·무작위 전리품은 추가하지 않습니다. 싱글플레이는 지원 대상이 아닙니다.
- 서버가 미니맵을 허용해야 지도에 표시됩니다. 서버의 일반 플레이어 지도 공개 설정은 별개입니다.

## Installation

Server and all clients must have identical mod files. Copy `Contents/mods/ZomputSurvivorSignal` into your local `Zomboid/mods` directory or install the Workshop release. Enable Mod ID `ZomputSurvivorSignal` (B42 server INI representation: `\ZomputSurvivorSignal`).

This repository contains only the mod, its artwork, documentation and tests. Deployment credentials, NAS addresses, server configuration, saves and private test infrastructure belong outside this repository.

## Tests

Run `lua tests/server_spec.lua` from the repository root (Lua 5.1+, or fengari). This checks server rules with test doubles; it does not replace two-client multiplayer gameplay verification.
