#!/bin/bash

# Инициализируем переменные
ROOT_PATH=$(cd $(dirname $0) && pwd);
LOGIN="utm"
ADDRESS="192.168.0.11"
URL_BASE="/gost-ssl/rzs/dump/url-abuse.txt"
URL_UNSORT="$HOME/url_unsort.txt"
URL_SORT="$HOME/url_sort.txt"
URL_SLASH="$HOME/url_slash.txt"
EXCEPTIONS="$ROOT_PATH/exceptions.txt"
SCRIPT="$HOME/url_script.txt"
COMMENT="ZAPRET"
COMMAND_REMOVE="/ip dns static remove [find comment=$COMMENT]"
COMMAND_IMPORT="import file-name=url_script.txt"
COMMAND_FLUSH="/ip dns cache flush"
REDIRECT="192.168.0.10"

# Функция получения доменного имени из строки
function convert {
  # Получаем доменное имя из переданного параметра
  STRING=`echo "$1" | awk -F/ '{print $3}'`
  # Получаем первые 4 символа доменного имени
  WWW=${STRING:0:4}
  # Если первые 4 символа равны www., то
  if [ "$WWW" = "www." ];
  then
    # Удаляем первые 4 символа из строки
    STRING=`echo "$STRING" | cut -c 5-`
  fi
}

# Если файл со списком запрещенных ресурсов существует, то
if [ -f "$URL_BASE" ];
then
  # Добавляем в скрипт команду очистки
  echo "$COMMAND_REMOVE" > "$SCRIPT"
  # Считываем адреса из файла запрещенных ресурсов
  while read RESOURCE;
  do
    # Конвертируем адрес
    convert "$RESOURCE"
    # Считываем адреса доменов из файла исключений
    while read EXCEPT;
    do
      # Адреса нет в списке исключений (устанавливаем дефолтовое значение)
      AVAILABLE="no"
      # Если адрес в списке исключений, то
      if [ "$STRING" == "$EXCEPT" ];
      then
        # Есть соответствие адрес - исключение
        AVAILABLE="yes"
        # Выходим из цикла
        break
      fi
    done < "$EXCEPTIONS"
    # Если адреса в списке исключений нет, то
    if [ "$AVAILABLE" == "no" ];
    then
      # Помещаем адрес во временный файл
      echo "$STRING" >> "$URL_UNSORT"
    fi
  done < "$URL_BASE"
  # Исключаем дублирующиеся строки из временного файла
  # и помещаем результат в новый файл
  cat "$URL_UNSORT" | sort -u > "$URL_SORT"
  # Заменяем в файле каждый символ . на \\\\.
  # и выгружаем результаты в другой файл
  cat "$URL_SORT" | sed 's/\./\\\\\\\\./g' > "$URL_SLASH"
  # Считываем модифицированные адреса доменов из файла
  while read URL;
  do
    # Добавляем к адресу спецсимволы
    URL="\"\\\".*\\\\.$URL\\\"\""
    # Формируем команду для добавления в  скрипт
    COMMAND_ADD="/ip dns static add comment=$COMMENT address=$REDIRECT name=$URL"
    # Добавляем новую команду в скрипт
    echo "$COMMAND_ADD" >> "$SCRIPT"
  done < "$URL_SLASH"
  # Добавляем в скипт команду сброса
  echo "$COMMAND_FLUSH" >> "$SCRIPT"
  # Отправляем файл скрипта на микротик
  scp "$SCRIPT" "$LOGIN@$ADDRESS:/"
  # Запускаем скрипт удаленно
  ssh "$LOGIN@$ADDRESS" "$COMMAND_IMPORT"
  # Удаляем временные файлы
  rm "$URL_UNSORT"
  rm "$URL_SORT"
  rm "$URL_SLASH"
  rm "$SCRIPT"
fi
