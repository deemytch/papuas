# Что это

Набор утилит "Парламентёр" предназначен для выполнения скриптов на серверах так, чтобы операторы не имели доступа к указанным серверам. Прокся, короче.
Народное название: Программно-аппаратная платформа удаленного администрирования автоматизированных систем. Сокращенно - ПАПУАС.

# Первоначальная настройка

1. Создать базу и пользователя
2. Отредактировать файл config/global.yml - внести туда имя базы, пользователя и пароль
3. Запустить ./dbsetup.sh
4. Прочесть справку по команде appsetup.rb
  ./appsetup.rb -h
5. Создать необходимые папки на серверах операторов
6. Надобавлять нужных серверов и пользователей
  При добавлении утилита проверяет наличие и доступность всех указанных серверов, пользователей и файлов ключей
  Можно использовать сокращённые имена серверов и не писать имя пользователя, если это есть в ~/.ssh/config
7. По готовности запустить ./bigbro.rb
  Он уйдёт в фон и будет сканировать сервера с исходниками
  с интервалом в секундах из config/global.yml[:global][:query_delay]
  Там же написано, куда он кладёт логи.
  Если при старте невозможно открыть лог-файл, утилита упадёт и пожалуется.

# Как это

Оператор пишет скрипт для выполнения задачи на сервере (Нода1). Затем пишет настроечный файл (doit-случайный-текст.yml) с параметрами запуска этого скрипта. Кладёт оба файла и, возможно, другие, необходимые для скрипта файлы, в заранее заданную папку на сервере (Источник1:/папка) и надеется на лучшее.

Утилита bigbro.rb каждые Ч секунд опрашивает папку (Источник1:/папка) на предмет наличия там новых поступлений. Увидев файл настроек doit*.yml он радостно загружает оттуда такие данные: 
* где взять скрипт
* есть ли дополнительные файлы
* на каких серверах (Нода1, Нода10) исполнять этот скрипт и какие данные (логин) для доступа к нодам использовать.

Весь вывод STDOUT и STDERR выполненного скрипта утилита складывает обратно в папку где взяла, переименовывает файл doit*.yml в doneit*.yml и дописывает в него имена файлов stderr.log, stdout.log и код возврата скрипта.

Образец файла задачи находится в *docs/doit-with-love.yml*

# Тут нужен админ

## Что где

Структура баз описана в файле docs/db.pdf
Скрипт генерации базы - dbsetup.rb

## Программа *appsetup.rb*

### Как это происходит

Вход и выполнение скрипта пользователя на целевом узле.

#### Ключ и логин для входа

1. используется имя пользователя, заданное в описании задачи, (разумеется если оно есть и в базе тоже)
2. используется имя пользователя, заданное в ~/.ssh/config
3. используется самое новое имя из базы по дате добавления
4. используется ключ (pem) из базы, связанный с найденным именем

#### При добавлении узла или источника в базу настроек:

1. ищется ключ, явно заданный в командной строке
2. используются настройки из .ssh/config на управляющем компьютере
3. ищем ключ #{user}@#{node}.#{port}.[rsa|ed25519|pem] в подпапке *keys*
4. Затем ключ преобразовывается в .pem формат и записывается в базу

На данном этапе проектирования предполагается использовать net-ssh + sshkit.
Если при отладке возникнут какие-то сбои (руби не всегда многопоточен), будет использоваться бинарный ssh из системы, выполняемый через задачи в sidekiq. В последнем случае понадобится установить и запустить redis, поскольку sidekiq использует его для сериализации задач.

Все задачи на всех серверах ставятся в очередь и выполняются приблизительно параллельно, это зависит от параметра bigbro.rb -j N и загрузки системы.

### Примеры

  ./appsetup.rb -h

## Программа *bigbro.rb*

Предназначена для сбора задач с источников и выполнения их на целевых узлах.
Результаты выводит в базу данных и в log-файл.
Параметр -j N, где N - целое число. Количество параллельных задач для выполнения на целевых узлах.
Параметр -q - вывод только в базу.
Параметр -t - тестовый режим.
* Проверка настроек
* Проверка базы на целостность и непротиворечивость
* Загрузка заданий
* Проверка наличия целевых узлов
* Логин на целевые узлы с указанными реквизитами
* Выполнения скриптов *НЕ ПРОИСХОДИТ*

Запуск: bigbro.rb start
Остановка: bigbro.rb stop
