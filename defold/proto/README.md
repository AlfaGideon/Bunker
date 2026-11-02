# Схемы Defold

Копия `.proto`-файлов движка Defold (тег `1.14.0`), нужная только для одной
цели: проверить текстовые ресурсы проекта (`*.gui`, `*.atlas`, `*.go`,
`*.collection`, `*.font`, `*.input_binding`) теми же схемами, которыми их
проверяет `bob.jar`. Так ошибка вида «нет поля `material` в `Atlas`» видна за
секунды локально и в CI, а не через пять минут после сборки APK.

Источник: <https://github.com/defold/defold> (каталоги `engine/*/proto`).
Лицензия — Defold License 1.0, см. `THIRD_PARTY.md`. Файлы не участвуют в
сборке APK и не попадают в бандл.

Проверка: `python3 tools/check_defold_files.py` (нужен `grpcio-tools`).
