# Инструкции для агентов (AGENTS.md)

Этот файл — правила для любых AI-агентов и разработчиков, работающих с репозиторием.

## О проекте

**Rust Road TD** — tower defense на несущемся по пустоши боевом грузовике в духе «Безумного Макса», с прокачкой машины в стиле Crossout. Android, портретный режим.

- Движок: **Godot 4.2+** (бесплатный, open source), рендерер **Mobile**.
- Язык: **GDScript** (строгая типизация где возможно).
- Вся графика **процедурная**: меши из примитивов, ржавые материалы, GPU-частицы (пыль, дым, взрывы). Бинарные ассеты не добавлять без крайней необходимости.
- **Арт-стиль — пост-апокалипсис пустоши**: ржавое железо, заклёпки, шипы, канистры, выгоревшее пустынное небо, пыль. Палитра — охра/ржавчина/копоть (`Junk.RUST_TONES`). Никакого неона. Новые элементы должны быть «самодельными на коленке»: обвесы, сварные швы, хлам.

## Правила работы

1. **Все правки пушить сразу в `main`** после каждого логического изменения. Коммиты осмысленные, на английском, `type: description` (feat/fix/refactor/docs/chore).
2. Перед пушем проверять: `godot --headless --path . --import` и `godot --headless --path . --quit-after N` без скриптовых ошибок (ошибки `mesh_get_surface_count` в headless — норма, это dummy-рендерер).
3. Не ломать мобильный ввод: тап — установка/выбор орудия, drag — орбита камеры, pinch — зум. Мышь эмулирует touch для отладки.
4. Держать производительность мобильной: рендерер `mobile`, частицы умеренно, тени только от солнца.
5. Тексты интерфейса и комментарии в коде — на русском.

## Концепция геймплея

Грузовик визуально мчится по дороге (мир скроллится назад мимо неподвижного грузовика). Рейдеры догоняют сзади, пристраиваются рядом и таранят. Игрок ставит орудия в 8 слотов на кузове и прокачивает саму фуру в «Гараже».

## Архитектура

| Файл | Ответственность |
|---|---|
| `scenes/Main.tscn` | Единственная сцена; всё собирается кодом из `Main.gd` |
| `scripts/Main.gd` | Композиция: пустынное окружение, свет, менеджеры, тапы (плоскость на высоте платформы), установка/выбор орудий, апгрейды фуры |
| `scripts/Junk.gd` | Статическая фабрика "ржавого железа": материалы, box/cyl/spike/wheel, пыль, взрывы |
| `scripts/Wasteland.gd` | Скроллящаяся пустошь: 3 тайла (дорога, скалы, остовы машин, столбы), `speed_scale` от движка |
| `scripts/Truck.gd` | Грузовик: кабина+цистерна+платформа, 8 слотов, колёса/тряска/выхлоп; Crossout-апгрейды с видимыми обвесами (`apply_upgrade`) |
| `scripts/TruckData.gd` | Данные апгрейдов фуры: armor/spikes/engine/drone, по 3 уровня |
| `scripts/WeaponData.gd` | Данные орудий: 6 типов × 3 уровня (mgun/flamer/harpoon/cannon/tesla/mortar) |
| `scripts/AbilityData.gd` | Данные способностей экипажа: залп/щит/нитро, кулдауны, цвета |
| `scripts/Abilities.gd` | Способности: залп по всем врагам, щит-клетка (неуязвимость GameState), нитро (форсаж, враги отстают) |
| `scripts/RoadEvents.gd` | Случайные события дороги: буря (режет `weapon_range_mult`, туман), мины за борт (вложенный класс `Mine`), сброс припасов, воздушная засада |
| `scripts/SoundFX.gd` | Процедурный синтез звука (PCM, без файлов): `_build_samples()` — банк, `play(name, vol, pitch)`; полифония 8, headless-безопасен |
| `scripts/RaiderCopter.gd` | Автожир рейдеров: парит над фурой, сбрасывает бомбы, потом камикадзе; в группе `enemies`, но НЕ в `enemies_alive` (не блокирует волну) |
| `scripts/Weapon.gd` | Орудие на слоте: самодельный визуал, поиск ближайшей цели, стрельба; стволы вдоль +Z (после look_at — разворот на PI) |
| `scripts/Projectile.gd` | Снаряды: bullet/flame/harpoon (замедление)/shell (сплэш) |
| `scripts/Enemy.gd` | Рейдер: догоняет, пристраивается на `attack_offset`, таранит; типы buggy/biker/ram/boss; смерть — кувырок и отставание |
| `scripts/WaveManager.gd` | Волны, чередование сторон спавна, босс каждые 5 волн, бонус волны ×движок |
| `scripts/GameState.gd` | Металлолом, HP фуры (max_hp растёт от брони), ремонт дробным накоплением; `reward_mult` (мета), `weapon_range_mult` (события), неуязвимость (щит) |
| `scripts/MetaProgress.gd` | Мета-прогрессия: чертежи с рейсов, 4 постоянных улучшения × 3 уровня, сейв JSON в `user://meta_progress.save` |
| `scripts/CampaignData.gd` | Данные кампании: 5 городов пустоши, 6 ресурсов, дороги (расстояние/опасность), шаблоны контрактов, здания базы, техи RESEARCH, рецепты RECIPES |
| `scripts/Campaign.gd` | Состояние кампании: кошелёк, трюм (вместимость), цены с дневным джиттером, контракты, находки дня (`poi_at()/resolve_poi()`), `arrive()/fail_run()`; сейв `user://campaign.save` |
| `scripts/MapScreen.gd` | Экран карты (CanvasLayer поверх боя): холст дорог, кнопки городов, рынок (купить/продать), доска контрактов; сигнал `travel_requested` в Main |
| `scripts/HUD.gd` | UI кодом: верх (лом, HP-бар, волна), арсенал, ГАРАЖ (апгрейды фуры), панель орудия, game over |

## Поток игры (кампания)

Игра стартует на **карте** (`MapScreen` виден, HUD скрыт, волны не активны). Игрок выбирает соседний город → `Main._on_travel()` задаёт `waves.run_length = 4 + dist*2` и `danger`, прячет карту и зовёт `waves.start()`. Конец рейса: победа — `waves.run_completed` → `campaign.arrive()` (лом в кошелёк, лут в трюм, контракты закрываются) → панель прибытия → `reload_current_scene()` обратно в карту. Смерть — `campaign.fail_run()` (половина груза горит) → game over → на карту. Релоад после каждого рейса — поэтому состояние держим в `Campaign`/`MetaProgress` и сохраняем до релоада.

## Геймплейные соглашения

- Экономика: старт 150 лома, 100 HP; бонус волны `25 + wave*6` (×1.25/ур. движка); демонтаж возвращает 60%.
- Сложность: HP рейдеров ×`(1 + (wave-1)*0.2)`, число `4 + wave`.
- Шипы: `ram_damage_multiplier = 1 - 0.3*ур.` и ранят атакующего; дрон: `1.5*ур.` HP/с.
- Новые орудия: `WeaponData.DEFS` + ветка в `Weapon._build_visual()` + при необходимости вид снаряда в `Projectile`.
- Новые апгрейды фуры: `TruckData.DEFS` + ветка в `Truck.apply_upgrade()` с обязательным видимым обвесом.
- Новые способности экипажа: `AbilityData.DEFS` + ветка в `Abilities.try_activate()` с процедурным визуалом. Легендарная способность: `"legendary": true` в DEFS + рецепт в `CampaignData.LEGENDARY_ABILITY_RECIPES` + `Campaign.forge_ability()` (вечный анлок в `leg_abilities`, сейвится) + `Main._sync_legendary_abilities()` (гейтинг и кнопки). ВНИМАНИЕ: голый `%` в format-строках feedback — только `%%`.
- Фазы босса в `Enemy._set_phase()`: 2 — ярость (быстрее/чаще бьёт), 3 — зовёт байкеров (`spawn_minions`) и ходит в разгонные тараны (×2.0 урона). Анонсы идут через `WaveManager.boss_event` в HUD.
- Плотность старших волн: фланговые колонны планируются в `WaveManager._launch_wave()` (`_flank_plan`, триггер `_check_flanks()` по `_spawned_count`, спавн сбоку через `_spawn({flank: ±1})`); диверсанты — флаг `sab` в очереди с 8-й волны → `Enemy.sab` → первый удар эмитит `GameState.weapon_jam_requested` → `Main._on_weapon_jam_requested()` зовёт `Weapon.jam(3.5)`.
- Перф-бюджеты: взрывы в группе `fx_explosion` (≥8 — не спавнить, ≥4 — без OmniLight), лампа `Weapon._flash` visible только при выстреле, снаряды в группе `projectiles`; бенч — docs/PERF.md.
- Мета «Бортмеханик»: `MetaProgress.DEFS.mechanic` → `mechanic_rate()` HP/сек; починка в `Main._process()` только при `waves.between_waves` (дроби копит `GameState.heal`).
- Встречи на трассе: `RoadEvents.encounter(title, desc, options)` → модалка `HUD.show_encounter()` (кнопки через `_rusty_button`, cb из опций, старт волны прячет); гейтинг `_maybe_encounter()` на фронте `between_waves`, лимит `ENCOUNTER_MAX_PER_RUN`, сброс в `Main._on_travel()`. Старые кнопки — только `remove_child` + `queue_free`, иначе перехватывают тапы до конца кадра!
- Обучение новичка: `scripts/Tutorial.gd` — шаги в `_steps()` (id/text/when/timeout), флаги в `MetaProgress.tutorial_flags` (сейв `tutorial_flags`); Main шлёт `tutorial.notify("travel"/"mounted"/"ability"/"arrival"/"gameover")`; баннер `HUD.show_hint()`, тап — `hint_dismissed` = шаг засчитан. Новый шаг = запись в `_steps()` + ветка в `_done_condition()`.
- Дороги 2.0: `ROUTES` — [A, B, dist, danger, флаг?]; ☠ при danger≥1.4 (`route_is_deadly`), 🐫 "caravan" (`route_is_caravan` → `RoadEvents.set_caravan_run()` — первое событие рейса гарантированный `trigger("supply")`). Новый город = запись в `CITIES` (name/icon/pos/desc/faction/mods [+home]) + дороги; POI/репутация/контракты подхватываются автоматом.
- Новые события дороги: ветка в `RoadEvents.trigger()` + анонс через сигнал `announced`. Дальность орудий глушить через `GameState.weapon_range_mult`.
- Новые мета-улучшения: `MetaProgress.DEFS` + метод бонуса, применяемый из `Main._ready()` при старте рейса. Магазин — в HUD game-over панели.
- Новые здания базы: `CampaignData.BUILDINGS` + эффект в `Campaign` (например `cargo_cap()` или `arrive()`-производство).
- Новые техи: `CampaignData.RESEARCH` + применение эффекта в `Main._apply_campaign_effects()`. Тикают рейсами (`arrive`/`fail_run`), цена = лом + ресурсы + чертежи (`bp`).
- Новые крафт-модули: `CampaignData.RECIPES` + ветка `match` в `Main._apply_campaign_effects()` по staged-иду.
- Воздушный босс (корсар): волна %10 в `WaveManager._spawn_ace()` — тот же `RaiderCopter` с `is_ace`, фазы как у тягача; считается в `enemies_alive`.
- Дневные моды: `CampaignData.DAILY_MODS` + `Campaign.daily_mods()` (сид = дата) + применение в `Main._apply_campaign_effects()` и/или `Campaign.price_of()`.
- Новые находки (POI): тип в `CampaignData.POI_TYPES` + ветка `match` в `Campaign.resolve_poi()`. Генерация детерминирована (`poi_for(city, day_seed)`), осмотр одноразовый за день (`poi_used: "day_seed:city"`), бросок фиксирован сидом — перезаход не рероллит.
- Мета-стартовые орудия: уровни `MetaProgress.DEFS["arsenal"]` → списки в `MetaProgress.START_WEAPONS`, монтируются в `Main._apply_campaign_effects()` с метой `free_start` (продаются за 0, иначе фарм лома).
- Репутация фракций: `CampaignData.REP_LEVELS` (пороги/титулы) + `Campaign.gain_rep()/rep_level()`, эффекты в `buy_price()`(−4%/ур., floor) и `sell_rate()`(+3%/ур.), награды контрактов ×(1+0.05·ур. заказчика) в `note_kill()`/`arrive()` (у контракта есть `origin`).
- Трофейные тачки: шаблон в `CampaignData.TROPHIES` (chance/salvage/scrap_price) + `WaveManager.enemy_killed(type)` → захват в `Main._on_enemy_killed()` → `campaign.arrive(..., captured)`; ангар — `MapScreen._render_hangar()` («Разобрать» в ресурсы / «Продать» за лом).
- Звук: только процедурный `SoundFX` (синтез в `_build_samples()`, полифония 8 голосов, push_frame покадрово — `push_frames` в 4.2 НЕТ). Крючки: `GameState.sfx` для орудий/таранов, `Main` для волн/боссов/способностей, `sfx` в HUD/MapScreen для кликов. Тряска камеры: `CameraRig.add_trauma()` (квадрат, затухает). Новые сэмплы балансируем громкостью в `play()`, ≤ 0.35 длины.
- Рекорды волн: `MetaProgress.best_wave` + `last_run_was_record`, пишутся в обоих концах рейса (`_on_game_over` и `_on_run_completed`), показываются в панелях и шапке карты.
- Эскорт: шаблон «escort» в `CampaignData.CONTRACT_POOL`; фургон `scripts/AllyVan.gd` спавнится в `Main._spawn_escort_if_needed()` при рейсе в город-точку; враги перенацеливаются через `Enemy.ally` + `WaveManager.ally`; исход — `Campaign.resolve_escort()` в `Main._on_run_completed()` до `arrive()`.
- Сезоны: `CampaignData.SEASONS` + `season_for(month, day)`; рантайм — `campaign.season()` (тестируется через `_season_override`); ценовые эффекты прямо в `price_of()/sell_rate()`, боевые — в `Main._apply_campaign_effects()`; шапка карты показывает сезон.
- Легендарки: `CampaignData.LEGENDARY_RECIPES` (weapon+level+needs по трофеям) → `campaign.forge()` складывает в `pending` → ветка `leg_*` в `Main._apply_campaign_effects()` монтирует с `free_start` (за 0 при разборке). UI — секция «Кузня» в ангаре.
- Военный Поезд: волны %15 в `_launch_wave()` (trainloko + traincar-и из `TYPES`), визуалы в `Enemy._build_trainloko/_build_traincar()`; «фаза отцепки» — `WaveManager._on_train_car_died()` (сцеп +22% скорости). Трофеи: TROPHIES["trainloko"/"traincar"].

## Сборка под Android

- **CI**: `.github/workflows/android.yml` собирает APK на каждый пуш в `main` (артефакт `RustRoadTD-apk`) и публикует релиз при теге `v*`.
- **Локально**: см. `docs/ANDROID_BUILD.md`.
- При смене версии Godot синхронно обновлять `GODOT_VERSION` в workflow и `config/features` в `project.godot`.
