# Автозапуск DeepSeek Harness (dsh web) в WSL2 при перезапуске ПК

Цель: после включения компьютера и входа в Windows GUI DeepSeek Harness
сам доступен по **http://127.0.0.1:3080** (из браузера Windows — работает
через localhost-форвардинг WSL2).

Схема из двух звеньев (оба обязательны):

1. **Windows**: при входе в систему запускается `start-wsl-on-logon.bat` —
   он будит WSL2-VM (сама по себе VM при включении ПК не стартует).
2. **WSL**: при старте VM скрипт `dsh-web-start.sh` поднимает `dsh web`
   (идемпотентно: если GUI уже работает — ничего не делает).

Среда: Ubuntu в WSL2, в `/etc/wsl.conf` уже стоит `[boot] systemd=true`
и `[user] default=sa`.

## Файлы

| Файл | Назначение |
|---|---|
| `start-services.sh` | Единая точка автозапуска: LightRAG + dsh web (для `[boot] command=`). |
| `lightrag-start.sh` | Идемпотентный запуск LightRAG-сервера (http://127.0.0.1:9621). |
| `dsh-web-start.sh` | Идемпотентный запуск dsh web (http://127.0.0.1:3080). `--foreground` — для systemd. |
| `dsh-web.service` | systemd user-юнит dsh web (вариант B). |
| `lightrag.service` | systemd user-юнит LightRAG (вариант B). |
| `start-wsl-on-logon.bat` | Автозагрузка WSL в Windows (шаг 3). |
| `wsl.conf.example` | Шаблон `/etc/wsl.conf` для варианта A. |

## Установка

### Шаг 1. Поставить скрипт в постоянное место

```bash
mkdir -p ~/.dsh/bin ~/.dsh/logs
cp /home/sa/work/dsh-autostart/dsh-web-start.sh ~/.dsh/bin/
chmod +x ~/.dsh/bin/dsh-web-start.sh

# Проверка (сейчас сервис уже работает — должно напечатать "уже работает"):
~/.dsh/bin/dsh-web-start.sh
```

Скрипт ищет `dsh` в этом порядке: `$DSH_BIN` → `PATH` → самый свежий
`~/.npm/_npx/*/node_modules/.bin/dsh`. Если путь изменится (обновление
через npx), можно зафиксировать его: `export DSH_BIN=...` или в юните.

### Шаг 2. WSL: поднять dsh web при старте VM — выберите ОДИН вариант

**Вариант A (рекомендуется) — `[boot] command=` в `/etc/wsl.conf`:**

Скрипт `start-services.sh` поднимает оба сервиса (LightRAG, затем dsh web):

```bash
mkdir -p ~/.dsh/bin
cp /home/sa/work/dsh-autostart/start-services.sh \
   /home/sa/work/dsh-autostart/lightrag-start.sh \
   /home/sa/work/dsh-autostart/dsh-web-start.sh ~/.dsh/bin/
chmod +x ~/.dsh/bin/*.sh

sudo cp /etc/wsl.conf /etc/wsl.conf.bak
sudo sed -i '/^\[boot\]/a command=/home/sa/.dsh/bin/start-services.sh' /etc/wsl.conf
cat /etc/wsl.conf   # убедиться, что строка в секции [boot]
```

**Вариант B — systemd user-юниты** (контроль через `systemctl`, автоперезапуск):

```bash
mkdir -p ~/.config/systemd/user
cp /home/sa/work/dsh-autostart/dsh-web.service \
   /home/sa/work/dsh-autostart/lightrag.service ~/.config/systemd/user/
loginctl enable-linger "$USER"          # user-сессия живёт без открытого терминала
systemctl --user daemon-reload
systemctl --user enable --now lightrag.service dsh-web.service
systemctl --user status lightrag.service dsh-web.service
```

> Варианты A и B совместимы (скрипт идемпотентен), но достаточно одного.

### Шаг 3. Windows: будить WSL при входе в систему

Самый простой способ — автозагрузка проводником:

```
Win+R → shell:startup → Enter
```

скопировать туда `start-wsl-on-logon.bat`.

Более надёжный вариант — Планировщик заданий:
* Создать задачу → триггер «При входе в пользователя» → действие:
`wsl.exe` аргументы `--exec true` (или путь к .bat).

Если в системе несколько WSL-дистрибутивов, в .bat укажите имя:
`wsl.exe -d Ubuntu-24.04 --exec true` (имя — из `wsl -l -v`).

## Проверка

```bash
# из WSL:
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3080/   # 401 = работает (нужен login)
```

из Windows: `wsl --shutdown`, затем просто запустить `wsl` (или включить
ПК заново и войти) → открыть **http://127.0.0.1:3080** в браузере.

## Лог и отладка

- Лог dsh web: `~/.dsh/logs/dsh-web.log`
- Лог LightRAG: `/home/sa/work/lightrag/logs/lightrag-server.log`
  (и собственный `/home/sa/work/lightrag/lightrag.log`)
- Лог systemd-юнита: `journalctl --user -u dsh-web -n 50`
  / `journalctl --user -u lightrag -n 50`
- VM не стартует? из Windows: `wsl -l -v` (Working = запущена),
  `wsl --shutdown` и повторить.
- Порт занят чем-то другим? сменить: `DSH_WEB_PORT=3081 ~/.dsh/bin/dsh-web-start.sh`
  (и тот же порт задать в конфиге dsh web, если используете флаг).

## Как это работает (кратко)

1. Windows: вход в систему → `start-wsl-on-logon.bat` → `wsl.exe --exec true`.
   Команда мгновенно завершается, но VM **остаётся живой**, потому что
   init'ом работает systemd (`[boot] systemd=true`).
2. WSL: при старте VM выполняется `command=` из `/etc/wsl.conf`
   (или стартуют user-юниты):
   - `lightrag-start.sh` — если порт 9621 не отвечает, поднимает
     `lightrag-server` (venv `/home/sa/work/lightrag/.venv`, конфиг `.env`,
     LLM/эмбеддинги — gpustack), лог `/home/sa/work/lightrag/logs/`;
   - `dsh-web-start.sh` — если порт 3080 не отвечает, поднимает
     `dsh web` (nohup/setsid, лог `~/.dsh/logs/`).
3. Браузер Windows: `127.0.0.1:3080` автоматически форвардится WSL2
   на адрес VM. LightRAG (9621) доступен агенту через плагин dsh-lightrag.
