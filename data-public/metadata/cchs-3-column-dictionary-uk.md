# Словник змінних `cchs-3.sqlite` (українською)

Оновлено: 2026-02-22  
Джерело схеми: `data-private/derived/cchs-3.sqlite` (таблиці `cchs_analytical`, `cchs_employed`, `cchs_unemployed`, `sample_flow`, `data_dictionary`).

---

## Загальна логіка Lane 3

- `cchs_analytical`: основна версія для аналізу — виключає позначені як «usesless/all null» поля та перейменовує решту у короткі англомовні назви.
- `cchs_employed`: підтаблиця з `employment_code == 1`.
- `cchs_unemployed`: підтаблиця «решта вибірки» (усі записи, де `employment_code != 1` або `NA`), тобто доповнення до `cchs_employed`.

---

## Колонки, виключені у `cchs_analytical`

- `adm_rno`
- `income_5cat`
- `employment_type`
- `work_schedule`
- `alcohol_type`
- `bmi_category`
- `dhhgage`

---

## Таблиця `cchs_analytical`: словник перейменувань

| Нова колонка | Було в Lane 2 | Пояснення |
|---|---|---|
| `absence_days_total` | `days_absent_total` | Загальна кількість днів відсутності (основний результат). |
| `absence_days_chronic` | `days_absent_chronic` | Дні відсутності через хронічний стан (чутливісний результат). |
| `abs_chronic_days` | `lopg040` | Дні відсутності через хронічну проблему. |
| `abs_injury_days` | `lopg070` | Дні відсутності через травму. |
| `abs_cold_days` | `lopg082` | Дні відсутності через застуду. |
| `abs_flu_days` | `lopg083` | Дні відсутності через грип/інфлюенцу. |
| `abs_stomach_flu_days` | `lopg084` | Дні через шлунковий грип/гастроентерит. |
| `abs_resp_infection_days` | `lopg085` | Дні через респіраторну інфекцію. |
| `abs_other_infection_days` | `lopg086` | Дні через інші інфекційні хвороби. |
| `abs_other_health_days` | `lopg100` | Дні через інші фізичні/психічні причини. |
| `weight_pooled` | `wts_m_pooled` | Вага для pooled-аналізу (оригінальна/2). |
| `weight_original` | `wts_m_original` | Первинна master-вага респондента. |
| `geo_region_id` | `geodpmf` | Географічний/стратифікаційний ідентифікатор. |
| `employment_code` | `lop_015` | Код зайнятості. |
| `proxy_code` | `adm_prx` | Код проксі-респондента. |
| `survey_cycle_id` | `cycle` | Код циклу (`0` або `1`). |
| `age_group_3` | `age_group` | Рекодована вікова група (3 категорії). |
| `sex_label` | `sex` | Стать (людиночитне поле). |
| `marital_status_label` | `marital_status` | Сімейний стан. |
| `education_level` | `education` | Рівень освіти. |
| `immigration_status_label` | `immigration_status` | Імміграційний статус. |
| `visible_minority_label` | `visible_minority` | Видима меншина / етнічна категорія. |
| `has_family_doctor_label` | `has_family_doctor` | Наявність сімейного лікаря. |
| `smoking_status_label` | `smoking_status` | Статус куріння. |
| `physical_activity_label` | `physical_activity` | Рівень фізичної активності. |
| `self_health_general_label` | `self_health_general` | Самооцінка загального здоров’я. |
| `self_health_mental_label` | `self_health_mental` | Самооцінка психічного здоров’я. |
| `health_vs_last_year_label` | `health_vs_lastyear` | Здоров’я порівняно з попереднім роком. |
| `activity_limitation_label` | `activity_limitation` | Обмеження активності. |
| `injury_past_year_label` | `injury_past_year` | Травма за останні 12 місяців. |
| `survey_cycle_label` | `cycle_f` | Факторна назва циклу опитування. |
| `household_size` | `dhhdghsz` | Розмір домогосподарства. |
| `fruit_veg_daily_total` | `fvcdgtot` | Загальна кількість порцій овочів/фруктів на день. |
| `chronic_arthritis` | `cc_arthritis` | Хронічний стан: артрит. |
| `chronic_back_problems` | `cc_back_problems` | Хронічний стан: проблеми спини. |
| `chronic_hypertension` | `cc_hypertension` | Хронічний стан: гіпертензія. |
| `chronic_migraine` | `cc_migraine` | Хронічний стан: мігрень. |
| `chronic_copd` | `cc_copd` | Хронічний стан: ХОЗЛ/бронхіт/емфізема. |
| `chronic_diabetes` | `cc_diabetes` | Хронічний стан: діабет. |
| `chronic_heart_disease` | `cc_heart_disease` | Хронічний стан: хвороба серця. |
| `chronic_cancer` | `cc_cancer` | Хронічний стан: рак. |
| `chronic_ulcer` | `cc_ulcer` | Хронічний стан: виразка. |
| `chronic_stroke` | `cc_stroke` | Хронічний стан: наслідки інсульту. |
| `chronic_bowel_disorder` | `cc_bowel_disorder` | Хронічний стан: розлади кишківника. |
| `chronic_fatigue_syndrome` | `cc_chronic_fatigue` | Хронічний стан: синдром хронічної втоми. |
| `chronic_chemical_sensitivity` | `cc_chemical_sensitiv` | Хронічний стан: хімічна чутливість. |
| `chronic_mood_disorder` | `cc_mood_disorder` | Хронічний стан: розлад настрою. |
| `chronic_anxiety_disorder` | `cc_anxiety_disorder` | Хронічний стан: тривожний розлад. |
| `survey_cycle` | (нове поле) | Людиночитна назва циклу з `survey_cycle_id`. |
| `employment_status` | (нове поле) | Людиночитний статус зайнятості з `employment_code`. |
| `proxy_status` | (нове поле) | Людиночитний статус проксі з `proxy_code`. |
| `has_any_absence` | (нове поле) | Індикатор наявності будь-яких днів відсутності (`Yes/No`). |

---

## Таблиця `sample_flow`

Зберігається без змін зі Stage/Lane 2; містить кроки та кількість респондентів після кожного кроку.

## Таблиця `data_dictionary`

Технічна таблиця, що містить перелік виключених колонок та мапу перейменувань для `cchs_analytical`.

---

> Примітка: `cchs_analytical` призначена для щоденної аналітики (короткі читабельні назви) і є основною Lane 3 таблицею.
