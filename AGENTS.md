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
6. После завершения каждого улучшения и успешного пуша в GitHub итоговый отчёт обязательно заканчивать разделом **«Варианты дальнейшего развития»**: предлагать 4–6 конкретных следующих задач, кратко объяснять пользу каждой и явно отмечать рекомендуемый приоритетный вариант.

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
| `scripts/UserSettings.gd` | Пользовательские настройки UI/звука/вибрации/тряски/эффектов; отдельный JSON `user://user_settings.save` |
| `scripts/RustButton.gd`, `scripts/RustHeader.gd` | Единые процедурные клёпаные кнопки и металлические заголовки; новые интерактивные элементы строить через них |
| `scripts/CityMarker.gd` | Безрамочная метка города: большая рисованная эмблема, переносимая подпись, статусы стоянки/POI |
| `scripts/SafeArea.gd` | Перевод Android safe area в координаты viewport; верхние/нижние панели не должны попадать под вырезы и системные жесты |
| `scripts/RaiderCopter.gd` | Автожир рейдеров: парит над фурой, сбрасывает бомбы, потом камикадзе; в группе `enemies`, но НЕ в `enemies_alive` (не блокирует волну) |
| `scripts/Weapon.gd` | Орудие на слоте: самодельный визуал, поиск ближайшей цели, стрельба; стволы вдоль +Z (после look_at — разворот на PI) |
| `scripts/Projectile.gd` | Снаряды: bullet/flame/harpoon (замедление)/shell (сплэш) |
| `scripts/Enemy.gd` | Рейдер: догоняет, пристраивается на `attack_offset`, таранит; типы buggy/biker/ram/boss; смерть — кувырок и отставание |
| `scripts/WaveManager.gd` | Волны, чередование сторон спавна, босс каждые 5 волн, бонус волны ×движок |
| `scripts/GameState.gd` | Металлолом, HP фуры (max_hp растёт от брони), ремонт дробным накоплением; `reward_mult` (мета), `weapon_range_mult` (события), неуязвимость (щит) |
| `scripts/MetaProgress.gd` | Мета-прогрессия: чертежи с рейсов, 4 постоянных улучшения × 3 уровня, сейв JSON в `user://meta_progress.save` |
| `scripts/CampaignData.gd` | Данные кампании: 5 городов пустоши, 6 ресурсов, дороги (расстояние/опасность), шаблоны контрактов, здания базы, техи RESEARCH, рецепты RECIPES |
| `scripts/Campaign.gd` | Состояние кампании: кошелёк, трюм, контракты, туман войны (`discovered_cities`), услуги городов, сюжет фракций, находки дня, `arrive()/fail_run()`; сейв `user://campaign.save` |
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
- Именованные трассы: `route_mastery` растёт только в `_on_run_completed()`. На уровне 3 ключ пишется в `mastered_routes`, один раз выдаются лом/запчасти/чертёж и скидка −3% (потолок −18%). Видимую награду строит `Truck.apply_route_cosmetics(mastered_count)`; она должна переживать смену корпуса через повторный вызов после `_apply_hull()`.
- Война дорог: `route_control[route_key] = city_id`; `advance_faction_war()` тикает после каждого исхода рейса и пишет максимум 20 записей в `war_log`. Недельная кампания хранится в `war_week/war_side/war_points/war_claimed`, сбрасывается по Unix-неделе и выдаёт цели 4/8/15 один раз.
- Финалы историй: `story_ending()` (`allied/mercenary/betrayed`) меняет цену/силу услуги, число контрактов и кольцо `CityMarker`. Эксклюзивные исследования используют поле `RESEARCH.ending`; гейтинг только через `research_ending_req_met()`.
- Разведконтракт: открывает цель, усиливает рейс и ставит `WaveManager.scout_boss`; финальная волна содержит ровно одного `scoutboss`. Тип врага не заменять на `boss`: он нужен для трофея `TROPHIES.scoutboss` и визуала `Enemy._build_scoutboss()`.
- Достижения: базовые и серии хранятся в `ACHIEVEMENTS`; счётчики торговли/трофеев — `achievement_stats`. Сигналы `achievement_unlocked` и `route_mastered` используют одну очередь плашек HUD; награды строго одноразовые.
- Лист карты (`MapScreen._sheet_body`) живёт в ScrollContainer — длинные списки крутятся; НЕ выносить наружу. Тач-мишени ≥40px по высоте, шрифты ≥12 (чекится аудитом `~/.smoke_tests/ui_audit.gd`: кнопки/шрифты/ширина ≤700).
- Рисованный UI-арт: `assets/ui/` — префиксы `w_` орудия, `res_` ресурсы, `ab_` способности, `c_` эмблемы городов, `st_` статусные пиктограммы, `t_` трофеи, `b_` постройки базы, `r_` техи лаборатории, `cr_` крафт-модули, `art_` сюжетные сцены (jpg), `map_bg` фон карты. Иконки 96px png (~15KB), сцены jpg q82. Подключение ТОЛЬКО с фолбэком `ResourceLoader.exists` (иконки-строки — хелпер `MapScreen._add_row_icon()`, в ангаре/базе при наличии арта эмодзи из текста убирается). Каждый новый файл добавлять в `_asset_list()` аудита и не забывать `--import` перед проверками.
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
- Абордаж (угон добитых): лёгкие типы в `Enemy.BOARDABLE`; при HP<30% (и пока `hook_attempted` ложно) враг `boardable()` и получает пульсирующий маркер (`_check_hook_mark` из `take_damage`). Тап по дороге: `Main._handle_tap` → `_try_board_at()` (проекция `unproject_position`, мишень 110px, после проверок слотов чтобы не ломать установку орудий) → `_attempt_board()`: `apply_hook()` тормозит через тот же `_slow_mult/_slow_timer`, что и гарпун; успех `Main.board_chance` (var! в тестах 0.0/1.0) → трофей принудительно + `Enemy.capture()` (без взрыва и лома, `died.emit(0)` — волна/контракты считают), `_boarded_pending[type]` гасит повторный случайный захват в `_on_enemy_killed`; провал → `Enemy.enrage()` (+урон/скорость). Разовая подсказка — `meta.mark_tutorial("boarding")` из `Main._process`.
- Звук: только процедурный `SoundFX` (синтез в `_build_samples()`, полифония 8 голосов, push_frame покадрово — `push_frames` в 4.2 НЕТ). Крючки: `GameState.sfx` для орудий/таранов, `Main` для волн/боссов/способностей, `sfx` в HUD/MapScreen для кликов. Тряска камеры: `CameraRig.add_trauma()` (квадрат, затухает). Новые сэмплы балансируем громкостью в `play()`, ≤ 0.35 длины.
- Рекорды волн: `MetaProgress.best_wave` + `last_run_was_record`, пишутся в обоих концах рейса (`_on_game_over` и `_on_run_completed`), показываются в панелях и шапке карты.
- Эскорт: шаблон «escort» в `CampaignData.CONTRACT_POOL`; фургон `scripts/AllyVan.gd` спавнится в `Main._spawn_escort_if_needed()` при рейсе в город-точку; враги перенацеливаются через `Enemy.ally` + `WaveManager.ally`; исход — `Campaign.resolve_escort()` в `Main._on_run_completed()` до `arrive()`.
- Сезоны: `CampaignData.SEASONS` + `season_for(month, day)`; рантайм — `campaign.season()` (тестируется через `_season_override`); ценовые эффекты прямо в `price_of()/sell_rate()`, боевые — в `Main._apply_campaign_effects()`; шапка карты показывает сезон.
- Корпуса (Crossout-лесенка): `CampaignData.HULLS` (slots/hp_mult/parts/scrap/workshop) + `HULL_ORDER`; владение/сборка/выбор — `Campaign.can_build_hull()/build_hull()/select_hull()` (гейт = уровень мастерской); миграция ветеранских сейвов → багги+фура. `Truck.set_hull(id)` пересобирает геометрию/слоты — ТОЛЬКО до монтировки орудий (правило: `Main._apply_hull()` на старте сцены и по сигналу `MapScreen.hull_changed`; обвесы гаража привязаны к `_bed_len/_bed_w/_cab_z`). Пустая платформа в рейс получает штатный пулемёт `free_start` (продажа 0). Новый корпус = def + билдер в Truck + иконка `assets/ui/h_*.png` + строка в аудите.
- Учебный профиль старта: `campaign.runs_finished < 2` и корпус «buggy» → `run_length ≤ 3`, `danger ≤ 0.7` (Main._on_travel), штатный пулемёт при этом сразу ур.2. Запчасти: ресурс `parts` (лут ~8% доля, распил любого трофея, рынок) — топливо крафта корпусов.
- Легендарки: `CampaignData.LEGENDARY_RECIPES` (weapon+level+needs по трофеям) → `campaign.forge()` складывает в `pending` → ветка `leg_*` в `Main._apply_campaign_effects()` монтирует с `free_start` (за 0 при разборке). UI — секция «Кузня» в ангаре.
- Военный Поезд: волны %15 в `_launch_wave()` (trainloko + traincar-и из `TYPES`), визуалы в `Enemy._build_trainloko/_build_traincar()`; «фаза отцепки» — `WaveManager._on_train_car_died()` (сцеп +22% скорости). Трофеи: TROPHIES["trainloko"/"traincar"].

## Сборка под Android

- **CI**: `.github/workflows/android.yml` собирает APK на каждый пуш в `main` (артефакт `RustRoadTD-apk`) и публикует релиз при теге `v*`.
- **Локально**: см. `docs/ANDROID_BUILD.md`.
- При смене версии Godot синхронно обновлять `GODOT_VERSION` в workflow и `config/features` в `project.godot`.
